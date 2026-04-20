# frozen_string_literal: true

require 'aasm'
require_relative '../../repos/session_repo'
require_relative '../../repos/test_repo'
require_relative '../../repos/question_repo'
require_relative '../../repos/option_repo'
require_relative '../../repos/attempt_repo'
require_relative '../../repos/user_repo'
require_relative '../messages'
require_relative '../keyboards'
require 'telegram/bot'

class StudentFSM
  include AASM

  attr_reader :update, :bot, :user, :session, :chat_id

  aasm do
    state :idle, initial: true
    state :wait_for_change
    state :waiting_name
    state :waiting_code
    state :ready
    state :waiting_answer
    state :finished

    event :start_student_mode do
      transitions from: :idle, to: :wait_for_change
    end

    event :set_name_mode do
      transitions from: :wait_for_change, to: :waiting_name
    end

    event :set_code_mode do
      transitions from: :wait_for_change, to: :waiting_code
    end

    event :name_entered do
      transitions from: :waiting_name, to: :wait_for_change
    end

    event :enter_access_code do
      transitions from: :waiting_code, to: :ready
    end

    event :begin_test do
      transitions from: :ready, to: :waiting_answer
    end

    event :answer_question do
      transitions from: :waiting_answer, to: :waiting_answer
    end

    event :complete_test do
      transitions from: :waiting_answer, to: :finished
    end

    event :restart_test do
      transitions from: :finished, to: :ready
    end

    event :exit_test do
      transitions from: :finished, to: :idle
    end

    event :go_back do
      transitions from: [:wait_for_change], to: :idle
      transitions from: %i[waiting_name waiting_code ready finished waiting_answer], to: :wait_for_change
    end
  end

  def self.handle(update, bot, user)
    session = SessionRepo.find_or_create(user[:id])
    fsm = new(update, bot, user, session)

    if update.is_a?(Telegram::Bot::Types::Message)
      text = update.text.to_s.strip
      fsm.process_text_message(text)
    elsif update.is_a?(Telegram::Bot::Types::CallbackQuery)
      fsm.process_callback_query(update.data.to_s)
    end
  end

  def initialize(update, bot, user, session)
    @update = update
    @bot = bot
    @user = user
    @session = session
    @chat_id = extract_chat_id

    aasm.current_state = @session[:state].to_sym if @session[:state]
  end

  def extract_chat_id
    if @update.is_a?(Telegram::Bot::Types::Message)
      @update.chat.id
    elsif @update.is_a?(Telegram::Bot::Types::CallbackQuery)
      @update.message&.chat&.id || @update.from.id
    end
  end

  def process_text_message(text)
    return if handle_mode_switch(text)
    return if handle_mode_confirmation(text)
    return if handle_back_button(text)

    send(:"handle_#{aasm.current_state}", text)
  end

  def process_callback_query(data)
    return unless data.start_with?('answer:')

    handle_answer_callback(data)
  end

  private

  def handle_mode_switch(text)
    return false unless text == 'Я ученик'

    if @user[:mode] && @user[:mode] != 'student'
      SessionRepo.update(@session[:id], pending_mode: 'student')
      @bot.api.send_message(
        chat_id: @chat_id,
        text: 'Вы уже в режиме автора. Переключиться? (да/нет)',
        reply_markup: Keyboards.confirm_change_mode
      )
      return true
    end

    # Нормальный вход в student FSM
    start_student_mode if aasm.current_state == :idle

    UserRepo.set_mode(@user[:id], 'student')
    SessionRepo.update(@session[:id], state: aasm.current_state.to_s, pending_mode: nil)

    @bot.api.send_message(
      chat_id: @chat_id,
      text: 'Выберите действие:',
      reply_markup: Keyboards.student_start
    )
    true
  end

  def handle_mode_confirmation(text)
    return false unless @session[:pending_mode] == 'student'

    if text == 'Да'
      start_student_mode if aasm.current_state == :idle
      UserRepo.set_mode(@user[:id], 'student')
      SessionRepo.update(@session[:id], pending_mode: nil, state: aasm.current_state.to_s)
      @bot.api.send_message(
        chat_id: @chat_id,
        text: 'Режим переключён. Выберите действие:',
        reply_markup: Keyboards.student_start
      )
    else
      SessionRepo.update(@session[:id], pending_mode: nil)
      @bot.api.send_message(chat_id: @chat_id, text: 'Переключение отменено.')
    end
    true
  end

  def handle_back_button(text)
    return false unless text == 'Назад'

    if aasm.current_state != :idle
      go_back
      SessionRepo.update(@session[:id], state: aasm.current_state.to_s)
    end

    case aasm.current_state
    when :idle
      UserRepo.clear_mode(@user[:id])
      @bot.api.send_message(
        chat_id: @chat_id,
        text: Messages::START,
        reply_markup: Keyboards.start_menu
      )
    when :wait_for_change
      @bot.api.send_message(
        chat_id: @chat_id,
        text: 'Выберите действие:',
        reply_markup: Keyboards.student_start
      )
    end
    true
  end

  # ВАЖНО: ничего не шлём из idle, чтобы не было "лишнего главного меню"
  def handle_idle(_text)
    # no-op
  end

  def handle_wait_for_change(text)
    case text
    when 'Задать имя пользователя'
      set_name_mode
      SessionRepo.update(@session[:id], state: aasm.current_state.to_s)
      @bot.api.send_message(
        chat_id: @chat_id,
        text: 'Введите ваше имя:',
        reply_markup: Keyboards.back_button
      )
    when 'Ввести код доступа'
      set_code_mode
      SessionRepo.update(@session[:id], state: aasm.current_state.to_s)
      @bot.api.send_message(
        chat_id: @chat_id,
        text: 'Введите код доступа:',
        reply_markup: Keyboards.back_button
      )
    end
  end

  def handle_waiting_name(text)
    name_entered
    UserRepo.update_name(@user[:id], text)
    SessionRepo.update(@session[:id], state: aasm.current_state.to_s)
    @bot.api.send_message(
      chat_id: @chat_id,
      text: "✅ Имя сохранено: #{text}\n\nВыберите действие:",
      reply_markup: Keyboards.student_start
    )
  end

  def handle_waiting_code(text)
    test = TestRepo.find_by_code(text)

    if test
      enter_access_code
      SessionRepo.update(
        @session[:id],
        state: aasm.current_state.to_s,
        test_id: test[:id],
        current_question_pos: 1,
        correct_count: 0,
        started_at: Time.now
      )
      @bot.api.send_message(chat_id: @chat_id, text: "✅ Код найден!\n\n📝 Тест: #{test[:title]}")
      @bot.api.send_message(chat_id: @chat_id, text: "Описание: #{test[:description]}") if test[:description]
      @bot.api.send_message(
        chat_id: @chat_id,
        text: "Нажмите 'Начать' чтобы пройти тест.",
        reply_markup: Keyboards.start_test_menu
      )
    else
      @bot.api.send_message(
        chat_id: @chat_id,
        text: '❌ Код не найден. Попробуйте ещё раз:',
        reply_markup: Keyboards.back_button
      )
    end
  end

  def handle_ready(text)
    return unless text == 'Начать'

    begin_test
    SessionRepo.update(@session[:id], state: aasm.current_state.to_s)
    @session = SessionRepo.find_or_create(@user[:id])
    show_question
  end

  def handle_waiting_answer(_text)
    # ответы тут приходят через callback, текст игнорируем
  end

  def handle_finished(text)
    case text
    when 'Пройти заново'
      restart_test
      SessionRepo.update(
        @session[:id],
        state: aasm.current_state.to_s,
        current_question_pos: 1,
        correct_count: 0,
        started_at: Time.now
      )
      @bot.api.send_message(
        chat_id: @chat_id,
        text: "Нажмите 'Начать' чтобы пройти тест заново.",
        reply_markup: Keyboards.start_test_menu
      )
    when 'Выйти'
      exit_test
      UserRepo.clear_mode(@user[:id])
      SessionRepo.update(@session[:id], state: aasm.current_state.to_s)
      @bot.api.send_message(
        chat_id: @chat_id,
        text: Messages::START,
        reply_markup: Keyboards.start_menu
      )
    end
  end

  def handle_answer_callback(data)
    begin
      @bot.api.answer_callback_query(callback_query_id: @update.id) if @update.respond_to?(:id)
    rescue StandardError => e
      warn "[Callback Answer Error] #{e.class}: #{e.message}"
    end

    parts = data.split(':')
    option_id = parts[2].to_i

    opt = OptionRepo.find_by_id(option_id)
    SessionRepo.update(@session[:id], correct_count: @session[:correct_count] + 1) if opt && opt[:is_correct]

    SessionRepo.update(@session[:id], current_question_pos: @session[:current_question_pos] + 1)
    @session = SessionRepo.find_by_id(@session[:id])

    test = TestRepo.find_by_id(@session[:test_id])
    questions = QuestionRepo.by_test(test[:id])

    if @session[:current_question_pos] > questions.size
      complete_test
      SessionRepo.update(@session[:id], state: aasm.current_state.to_s)
      finish_test(test, questions.size)
    else
      answer_question
      SessionRepo.update(@session[:id], state: aasm.current_state.to_s)
      show_question
    end
  end

  def show_question
    test = TestRepo.find_by_id(@session[:test_id])
    questions = QuestionRepo.by_test(test[:id])
    q = questions.find { |x| x[:position] == @session[:current_question_pos] }
    return unless q

    options = OptionRepo.by_question(q[:id])
    keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard: options.map do |o|
        [Telegram::Bot::Types::InlineKeyboardButton.new(
          text: o[:text],
          callback_data: "answer:#{q[:id]}:#{o[:id]}"
        )]
      end
    )

    progress = "#{@session[:current_question_pos]}/#{questions.size}"
    @bot.api.send_message(
      chat_id: @chat_id,
      text: "📌 Вопрос #{progress}:\n\n#{q[:text]}",
      reply_markup: keyboard
    )
  end

  def finish_test(test, total)
    finished_at = Time.now
    duration_sec = (@session[:started_at] ? (finished_at - @session[:started_at]) : 0).to_i

    AttemptRepo.create(
      test_id: test[:id],
      student_user_id: @user[:id],
      student_name: @user[:name],
      correct_count: @session[:correct_count],
      total_count: total,
      started_at: @session[:started_at],
      finished_at:,
      duration_sec:
    )

    author = UserRepo.find_by_id(test[:author_user_id])
    date_str = finished_at.strftime('%d.%m.%Y %H:%M')
    duration_min = (duration_sec / 60.0).round(1)
    percentage = (total.positive? ? (@session[:correct_count].to_f / total) * 100 : 0).round(1)

    if author
      @bot.api.send_message(
        chat_id: author[:telegram_id],
        text: "✅ Тест завершён\n\n" \
              "📝 Тест: #{test[:title]}\n" \
              "👤 Ученик: #{@user[:name] || 'Без имени'}\n" \
              "🎯 Результат: #{@session[:correct_count]} из #{total} (#{percentage}%)\n" \
              "📅 Дата: #{date_str}\n" \
              "⏱️ Время: #{duration_min} мин"
      )
    end

    @bot.api.send_message(
      chat_id: @chat_id,
      text: "🎉 Тест завершён!\n\n" \
            "📊 Результат: #{@session[:correct_count]} из #{total} (#{percentage}%)\n" \
            "⏱️ Время прохождения: #{duration_min} мин",
      reply_markup: Keyboards.finish_menu
    )
  end
end

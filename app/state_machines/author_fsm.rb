# frozen_string_literal: true

require 'json'
require 'aasm'
require_relative '../../repos/draft_repo'
require_relative '../../repos/test_repo'
require_relative '../../repos/question_repo'
require_relative '../../repos/option_repo'
require_relative '../../repos/session_repo'
require_relative '../../repos/user_repo'
require_relative '../../services/access_code_generator'
require_relative '../../services/test_editor'
require_relative '../keyboards'
require_relative '../messages'

class AuthorFSM
  include AASM

  attr_reader :update, :bot, :user, :draft, :session, :chat_id

  aasm do
    state :idle, initial: true
    state :waiting_title
    state :waiting_description
    state :waiting_question_text
    state :waiting_options
    state :waiting_correct
    state :waiting_next_question
    state :waiting_edit_test_id
    state :edit_or_delete_menu
    state :editing_test_menu
    state :editing_title
    state :editing_description
    state :editing_question_pos
    state :editing_question_text
    state :editing_options
    state :editing_correct
    state :confirm_delete

    event :start_create_test do
      transitions from: :idle, to: :waiting_title
    end

    event :enter_title do
      transitions from: :waiting_title, to: :waiting_description
    end

    event :enter_description do
      transitions from: :waiting_description, to: :waiting_question_text
    end

    event :enter_question_text do
      transitions from: :waiting_question_text, to: :waiting_options
    end

    event :enter_options do
      transitions from: :waiting_options, to: :waiting_correct
    end

    event :enter_correct_answer do
      transitions from: :waiting_correct, to: :waiting_next_question
    end

    event :continue_next_question do
      transitions from: :waiting_next_question, to: :waiting_question_text
    end

    event :finish_test do
      transitions from: :waiting_next_question, to: :idle
    end

    event :show_my_tests do
      transitions from: :idle, to: :waiting_edit_test_id
    end

    event :select_test_for_edit do
      transitions from: :waiting_edit_test_id, to: :edit_or_delete_menu
    end

    event :choose_edit_test do
      transitions from: :edit_or_delete_menu, to: :editing_test_menu
    end

    event :choose_delete_test do
      transitions from: :edit_or_delete_menu, to: :confirm_delete
    end

    event :edit_title do
      transitions from: :editing_test_menu, to: :editing_title
    end

    event :edit_description do
      transitions from: :editing_test_menu, to: :editing_description
    end

    event :edit_questions do
      transitions from: :editing_test_menu, to: :editing_question_pos
    end

    event :back_to_edit_or_delete do
      transitions from: %i[
        editing_test_menu editing_title editing_description
        editing_question_pos editing_question_text editing_options
        editing_correct
      ], to: :edit_or_delete_menu
    end

    event :back_to_editing_test do
      transitions from: %i[
        editing_title editing_description editing_question_pos
        editing_question_text editing_options editing_correct
      ], to: :editing_test_menu
    end

    event :enter_new_title do
      transitions from: :editing_title, to: :editing_test_menu
    end

    event :enter_new_description do
      transitions from: :editing_description, to: :editing_test_menu
    end

    event :enter_question_position do
      transitions from: :editing_question_pos, to: :editing_question_text
    end

    event :enter_edited_question_text do
      transitions from: :editing_question_text, to: :editing_options
    end

    event :enter_edited_options do
      transitions from: :editing_options, to: :editing_correct
    end

    event :enter_edited_correct do
      transitions from: :editing_correct, to: :editing_test_menu
    end

    event :confirm_delete_test do
      transitions from: :confirm_delete, to: :idle
    end

    event :cancel_delete do
      transitions from: :confirm_delete, to: :edit_or_delete_menu
    end

    event :go_back do
      transitions from: %i[
        waiting_title waiting_description waiting_question_text
        waiting_options waiting_correct waiting_next_question
        waiting_edit_test_id edit_or_delete_menu confirm_delete
      ], to: :idle
    end
  end

  def self.handle(update, bot, user)
    return unless update.is_a?(Telegram::Bot::Types::Message)

    fsm = new(update, bot, user)
    fsm.process_message(update.text.to_s.strip)
  end

  def initialize(update, bot, user)
    @update = update
    @bot = bot
    @user = user
    @chat_id = @update.chat.id
    @draft = DraftRepo.find_or_create(user[:id])
    @session = SessionRepo.find_or_create(user[:id])

    aasm.current_state = @draft[:state].to_sym if @draft[:state]
  end

  def process_message(text)
    return if handle_mode_switch(text)
    return if handle_mode_confirmation(text)
    return if handle_author_shortcuts(text)
    return if handle_back_button(text)

    send(:"handle_#{aasm.current_state}", text)
  end

  private

  # Глобальные команды автора из ЛЮБОГО состояния
  def handle_author_shortcuts(text)
    return false unless @user[:mode] == 'author'
    return false unless ['Создать тест', 'Мои тесты'].include?(text)

    case text
    when 'Создать тест'
      reset_author_draft_to_idle!
      start_create_test
      DraftRepo.update(@draft[:id], state: aasm.current_state.to_s)

      @bot.api.send_message(
        chat_id: @chat_id,
        text: '📝 Введите название теста:',
        reply_markup: Keyboards.back_button
      )
      true

    when 'Мои тесты'
      reset_author_draft_to_idle!
      show_my_tests
      tests = TestRepo.by_author(@user[:id])

      if tests.empty?
        # если тестов нет — остаёмся в author menu, НЕ выходим в start
        aasm.current_state = :idle
        DraftRepo.update(@draft[:id], state: 'idle')
        @bot.api.send_message(
          chat_id: @chat_id,
          text: '📚 У вас нет тестов.',
          reply_markup: Keyboards.author_menu
        )
      else
        msg = "📚 Ваши тесты:\n\n#{tests.map { |t| format_test_card(t) }.join("\n\n")}"
        @bot.api.send_message(chat_id: @chat_id, text: msg)
        @bot.api.send_message(
          chat_id: @chat_id,
          text: 'Введите ID теста для редактирования или удаления:',
          reply_markup: Keyboards.back_button
        )
        DraftRepo.update(@draft[:id], state: aasm.current_state.to_s) # waiting_edit_test_id
      end
      true
    end
  end

  def handle_mode_switch(text)
    return false unless text == 'Я автор'

    if @user[:mode] && @user[:mode] != 'author'
      SessionRepo.update(@session[:id], pending_mode: 'author')
      @bot.api.send_message(
        chat_id: @chat_id,
        text: 'Вы уже в режиме ученика. Переключиться? (да/нет)',
        reply_markup: Keyboards.confirm_change_mode
      )
      return true
    end

    UserRepo.set_mode(@user[:id], 'author')
    DraftRepo.update(@draft[:id], state: 'idle')
    @bot.api.send_message(
      chat_id: @chat_id,
      text: '✍️ Режим автора активирован',
      reply_markup: Keyboards.author_menu
    )
    true
  end

  def handle_mode_confirmation(text)
    return false unless @session[:pending_mode] == 'author'

    if text == 'Да'
      UserRepo.set_mode(@user[:id], 'author')
      SessionRepo.update(@session[:id], pending_mode: nil)
      DraftRepo.update(@draft[:id], state: 'idle')
      @bot.api.send_message(
        chat_id: @chat_id,
        text: '✍️ Режим автора активирован',
        reply_markup: Keyboards.author_menu
      )
    else
      SessionRepo.update(@session[:id], pending_mode: nil)
      @bot.api.send_message(chat_id: @chat_id, text: 'Переключение отменено.')
    end
    true
  end

  def handle_back_button(text)
    return false unless text == 'Назад'

    case aasm.current_state
    when :idle
      # только тут выходим из author-режима в старт
      UserRepo.clear_mode(@user[:id])
      DraftRepo.update(@draft[:id], state: 'idle')
      @bot.api.send_message(chat_id: @chat_id, text: Messages::START, reply_markup: Keyboards.start_menu)

    when :editing_title, :editing_description, :editing_question_pos, :editing_question_text, :editing_options, :editing_correct
      back_to_editing_test
      DraftRepo.update(@draft[:id], state: aasm.current_state.to_s)
      @bot.api.send_message(chat_id: @chat_id, text: '✏️ Выберите что редактировать:',
                            reply_markup: Keyboards.editing_test_menu)

    when :editing_test_menu
      back_to_edit_or_delete
      DraftRepo.update(@draft[:id], state: aasm.current_state.to_s)
      @bot.api.send_message(chat_id: @chat_id, text: '✏️ Выберите действие:', reply_markup: Keyboards.edit_menu)

    when :edit_or_delete_menu, :waiting_edit_test_id, :confirm_delete,
      :waiting_title, :waiting_description, :waiting_question_text,
      :waiting_options, :waiting_correct, :waiting_next_question
      go_back
      DraftRepo.update(@draft[:id], state: aasm.current_state.to_s) # idle
      # ВАЖНО: режим автора сохраняем
      @bot.api.send_message(chat_id: @chat_id, text: '✍️ Меню автора', reply_markup: Keyboards.author_menu)

    else
      DraftRepo.update(@draft[:id], state: aasm.current_state.to_s)
      @bot.api.send_message(chat_id: @chat_id, text: '✍️ Меню автора', reply_markup: Keyboards.author_menu)
    end
    true
  end

  def format_test_card(test)
    lines = []
    lines << "#{test[:id]} — #{test[:title]}"
    desc = test[:description].to_s.strip
    lines << "📝 #{desc}" unless desc.empty?
    lines << "📋 Код: #{test[:access_code]}"
    lines.join("\n")
  end

  def handle_idle(text)
    case text
    when 'Создать тест'
      start_create_test
      DraftRepo.update(@draft[:id], state: aasm.current_state.to_s)
      @bot.api.send_message(chat_id: @chat_id, text: '📝 Введите название теста:', reply_markup: Keyboards.back_button)

    when 'Мои тесты'
      show_my_tests
      tests = TestRepo.by_author(@user[:id])

      if tests.empty?
        @bot.api.send_message(chat_id: @chat_id, text: '📚 У вас нет тестов.', reply_markup: Keyboards.author_menu)
      else
        msg = "📚 Ваши тесты:\n\n#{tests.map { |t| format_test_card(t) }.join("\n\n")}"
        @bot.api.send_message(chat_id: @chat_id, text: msg)
        @bot.api.send_message(chat_id: @chat_id, text: 'Введите ID теста для редактирования или удаления:',
                              reply_markup: Keyboards.back_button)
        DraftRepo.update(@draft[:id], state: aasm.current_state.to_s)
      end
    end
  end

  # остальные handle_* и create_question_if_needed оставь как у тебя
  # (без изменений)
  def handle_waiting_title(text)
    enter_title
    DraftRepo.update(@draft[:id], draft_title: text, state: aasm.current_state.to_s)
    @bot.api.send_message(
      chat_id: @chat_id,
      text: "📖 Введите описание теста (или '-' чтобы пропустить):",
      reply_markup: Keyboards.back_button
    )
  end

  def handle_waiting_description(text)
    enter_description
    desc = text == '-' ? nil : text
    DraftRepo.update(@draft[:id], draft_description: desc, state: aasm.current_state.to_s)
    @bot.api.send_message(
      chat_id: @chat_id,
      text: '❓ Введите текст первого вопроса:',
      reply_markup: Keyboards.back_button
    )
  end

  def handle_waiting_question_text(text)
    enter_question_text
    DraftRepo.update(@draft[:id], draft_question_text: text, state: aasm.current_state.to_s)
    @bot.api.send_message(
      chat_id: @chat_id,
      text: '📋 Введите варианты ответов (каждый с новой строки):',
      reply_markup: Keyboards.back_button
    )
  end

  def handle_waiting_options(text)
    enter_options
    options = text.split("\n").map(&:strip).reject(&:empty?)

    if options.size < 2
      @bot.api.send_message(
        chat_id: @chat_id,
        text: '❌ Нужно минимум 2 варианта ответа. Попробуйте снова:'
      )
      return
    end

    DraftRepo.update(@draft[:id], draft_options_json: options.to_json, state: aasm.current_state.to_s)

    options_text = options.each_with_index.map { |opt, idx| "#{idx + 1}️⃣ #{opt}" }.join("\n")
    @bot.api.send_message(
      chat_id: @chat_id,
      text: "✅ Варианты:\n#{options_text}\n\nВведите номер правильного варианта (1..#{options.size}):",
      reply_markup: Keyboards.back_button
    )
  end

  def handle_waiting_correct(text)
    opts = JSON.parse(@draft[:draft_options_json] || '[]')
    correct_idx = text.to_i - 1

    if correct_idx.negative? || correct_idx >= opts.size
      @bot.api.send_message(
        chat_id: @chat_id,
        text: "❌ Неверный номер. Введите число от 1 до #{opts.size}:"
      )
      return
    end

    enter_correct_answer
    create_question_if_needed(opts, correct_idx)

    DraftRepo.update(
      @draft[:id],
      state: aasm.current_state.to_s,
      draft_question_text: nil,
      draft_options_json: nil
    )

    @bot.api.send_message(
      chat_id: @chat_id,
      text: "✅ Вопрос добавлен!\n\nДобавить следующий вопрос?",
      reply_markup: Keyboards.next_question_menu
    )
  end

  def handle_waiting_next_question(text)
    case text
    when 'Добавить вопрос'
      continue_next_question
      DraftRepo.update(@draft[:id], state: aasm.current_state.to_s)
      @bot.api.send_message(
        chat_id: @chat_id,
        text: '❓ Введите текст следующего вопроса:',
        reply_markup: Keyboards.back_button
      )
    when 'Завершить'
      finish_test
      DraftRepo.clear(@draft[:id])
      @bot.api.send_message(
        chat_id: @chat_id,
        text: '🎉 Тест успешно опубликован!',
        reply_markup: Keyboards.author_menu
      )
    end
  end

  def handle_waiting_edit_test_id(text)
    test_id = text.to_i
    test = TestRepo.find_by_id(test_id)

    if test && test[:author_user_id] == @user[:id]
      select_test_for_edit
      DraftRepo.update(@draft[:id], state: aasm.current_state.to_s, target_test_id: test_id)
      @bot.api.send_message(
        chat_id: @chat_id,
        text: '✏️ Выберите действие:',
        reply_markup: Keyboards.edit_menu
      )
    else
      @bot.api.send_message(
        chat_id: @chat_id,
        text: '❌ Неверный ID теста. Попробуйте ещё раз:',
        reply_markup: Keyboards.back_button
      )
    end
  end

  def handle_edit_or_delete_menu(text)
    case text
    when 'Редактировать тест'
      choose_edit_test
      DraftRepo.update(@draft[:id], state: aasm.current_state.to_s)
      @bot.api.send_message(
        chat_id: @chat_id,
        text: '✏️ Выберите что редактировать:',
        reply_markup: Keyboards.editing_test_menu
      )
    when 'Удалить тест'
      choose_delete_test
      DraftRepo.update(@draft[:id], state: aasm.current_state.to_s)
      @bot.api.send_message(
        chat_id: @chat_id,
        text: '⚠️ Подтвердите удаление теста:',
        reply_markup: Keyboards.confirm_delete_menu
      )
    end
  end

  def handle_editing_test_menu(text)
    case text
    when 'Редактировать название'
      edit_title
      DraftRepo.update(@draft[:id], state: aasm.current_state.to_s)
      @bot.api.send_message(
        chat_id: @chat_id,
        text: '📝 Введите новое название:',
        reply_markup: Keyboards.back_button
      )
    when 'Редактировать описание'
      edit_description
      DraftRepo.update(@draft[:id], state: aasm.current_state.to_s)
      @bot.api.send_message(
        chat_id: @chat_id,
        text: '📖 Введите новое описание:',
        reply_markup: Keyboards.back_button
      )
    when 'Редактировать вопросы'
      edit_questions
      DraftRepo.update(@draft[:id], state: aasm.current_state.to_s)
      @bot.api.send_message(
        chat_id: @chat_id,
        text: '❓ Введите номер вопроса для редактирования:',
        reply_markup: Keyboards.back_button
      )
    end
  end

  def handle_editing_title(text)
    enter_new_title
    TestRepo.update_title(@draft[:target_test_id], @user[:id], text)
    DraftRepo.update(@draft[:id], state: aasm.current_state.to_s)
    @bot.api.send_message(
      chat_id: @chat_id,
      text: '✅ Название обновлено.',
      reply_markup: Keyboards.editing_test_menu
    )
  end

  def handle_editing_description(text)
    enter_new_description
    TestRepo.update_description(@draft[:target_test_id], @user[:id], text)
    DraftRepo.update(@draft[:id], state: aasm.current_state.to_s)
    @bot.api.send_message(
      chat_id: @chat_id,
      text: '✅ Описание обновлено.',
      reply_markup: Keyboards.editing_test_menu
    )
  end

  def handle_editing_question_pos(text)
    pos = text.to_i
    test = TestRepo.find_by_id(@draft[:target_test_id])
    questions = QuestionRepo.by_test(test[:id])

    if pos < 1 || pos > questions.size
      @bot.api.send_message(
        chat_id: @chat_id,
        text: "❌ Неверный номер. В тесте #{questions.size} вопросов."
      )
      return
    end

    enter_question_position
    DraftRepo.update(@draft[:id], edit_question_pos: pos, state: aasm.current_state.to_s)
    @bot.api.send_message(
      chat_id: @chat_id,
      text: '❓ Введите новый текст вопроса:',
      reply_markup: Keyboards.back_button
    )
  end

  def handle_editing_question_text(text)
    enter_edited_question_text
    DraftRepo.update(@draft[:id], draft_question_text: text, state: aasm.current_state.to_s)
    @bot.api.send_message(
      chat_id: @chat_id,
      text: '📋 Введите новые варианты ответов (каждый с новой строки):',
      reply_markup: Keyboards.back_button
    )
  end

  def handle_editing_options(text)
    enter_edited_options
    options = text.split("\n").map(&:strip).reject(&:empty?)

    if options.size < 2
      @bot.api.send_message(
        chat_id: @chat_id,
        text: '❌ Нужно минимум 2 варианта ответа. Попробуйт�� снова:'
      )
      return
    end

    DraftRepo.update(@draft[:id], draft_options_json: options.to_json, state: aasm.current_state.to_s)

    options_text = options.each_with_index.map { |opt, idx| "#{idx + 1}️⃣ #{opt}" }.join("\n")
    @bot.api.send_message(
      chat_id: @chat_id,
      text: "✅ Варианты:\n#{options_text}\n\nВведите номер правильного варианта (1..#{options.size}):",
      reply_markup: Keyboards.back_button
    )
  end

  def handle_editing_correct(text)
    opts = JSON.parse(@draft[:draft_options_json] || '[]')
    correct_idx = text.to_i - 1

    if correct_idx.negative? || correct_idx >= opts.size
      @bot.api.send_message(
        chat_id: @chat_id,
        text: "❌ Неверный номер. Введите число от 1 до #{opts.size}:"
      )
      return
    end

    ok = TestEditor.replace_question(
      test_id: @draft[:target_test_id],
      position: @draft[:edit_question_pos],
      new_text: @draft[:draft_question_text],
      new_options: opts,
      correct_index: correct_idx
    )

    enter_edited_correct
    DraftRepo.update(
      @draft[:id],
      state: aasm.current_state.to_s,
      draft_question_text: nil,
      draft_options_json: nil,
      edit_question_pos: nil
    )

    msg = ok ? '✅ Вопрос обновлён.' : '❌ Вопрос не найден.'
    @bot.api.send_message(chat_id: @chat_id, text: msg, reply_markup: Keyboards.editing_test_menu)
  end

  def handle_confirm_delete(text)
    case text
    when 'Удалить'
      confirm_delete_test
      TestRepo.soft_delete(@draft[:target_test_id], @user[:id])
      DraftRepo.clear(@draft[:id])
      @bot.api.send_message(chat_id: @chat_id, text: '🗑️ Тест удалён.', reply_markup: Keyboards.author_menu)
    when 'Отмена'
      cancel_delete
      DraftRepo.update(@draft[:id], state: aasm.current_state.to_s)
      @bot.api.send_message(chat_id: @chat_id, text: 'Удаление отменено.', reply_markup: Keyboards.edit_menu)
    end
  end

  def create_question_if_needed(options, correct_idx)
    test_id = @draft[:target_test_id]

    if test_id.nil?
      code = AccessCodeGenerator.generate
      test_id = TestRepo.create(
        author_id: @user[:id],
        title: @draft[:draft_title],
        description: @draft[:draft_description],
        access_code: code
      )
      DraftRepo.update(@draft[:id], target_test_id: test_id)
      @bot.api.send_message(chat_id: @chat_id, text: "🎉 Тест создан!\n\n📋 Код доступа: #{code}")
    end

    questions = QuestionRepo.by_test(test_id)
    position = questions.size + 1
    q_id = QuestionRepo.create(test_id:, position:, text: @draft[:draft_question_text])
    OptionRepo.create_many(question_id: q_id, options:, correct_index: correct_idx)
  end

  def reset_author_draft_to_idle!
    DraftRepo.clear(@draft[:id])
    @draft = DraftRepo.find_or_create(@user[:id])
    aasm.current_state = :idle
    DraftRepo.update(@draft[:id], state: 'idle')
  end
end

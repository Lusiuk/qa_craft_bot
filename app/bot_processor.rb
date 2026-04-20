# frozen_string_literal: true

require_relative '../repos/user_repo'
require_relative 'messages'
require_relative 'keyboards'
require_relative 'state_machines/author_fsm'
require_relative 'state_machines/student_fsm'

class BotProcessor
  def self.call(raw_update, bot)
    message, callback = normalize_update(raw_update)
    return unless message || callback

    telegram_id, chat_id, text = extract_context(message, callback)
    return unless telegram_id && chat_id

    user = UserRepo.find_or_create(telegram_id)

    # /start
    if message && text == '/start'
      UserRepo.clear_mode(user[:id])
      safe_send(bot, chat_id, Messages::START, reply_markup: Keyboards.start_menu)
      return
    end

    # /whoami
    if message && text == '/whoami'
      show_profile(bot, chat_id, user)
      return
    end

    # Если режим уже выбран — маршрутизируем строго в одну FSM
    case user[:mode]
    when 'author'
      AuthorFSM.handle(callback || message, bot, user)
      return
    when 'student'
      StudentFSM.handle(callback || message, bot, user)
      return
    end

    # Режим НЕ выбран
    if message
      handle_mode_selection(message, bot, chat_id, user, text)
    else
      # callback без выбранного режима
      answer_callback_safely(bot, callback)
      safe_send(bot, chat_id, Messages::START, reply_markup: Keyboards.start_menu)
    end
  rescue StandardError => e
    warn "[BotProcessor Error] #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    safe_send(bot, chat_id, Messages::ERROR) if defined?(chat_id) && chat_id
  end

  def self.normalize_update(raw_update)
    if raw_update.respond_to?(:message) && raw_update.respond_to?(:callback_query)
      [raw_update.message, raw_update.callback_query]
    elsif raw_update.is_a?(Telegram::Bot::Types::Message)
      [raw_update, nil]
    elsif raw_update.is_a?(Telegram::Bot::Types::CallbackQuery)
      [nil, raw_update]
    else
      [nil, nil]
    end
  end

  def self.extract_context(message, callback)
    if message
      [message.from&.id, message.chat&.id, message.text.to_s.strip]
    elsif callback
      [callback.from&.id, callback.message&.chat&.id, nil]
    else
      [nil, nil, nil]
    end
  end

  def self.safe_send(bot, chat_id, text, **options)
    return unless bot && chat_id && text

    bot.api.send_message(chat_id:, text:, **options)
  rescue StandardError => e
    warn "[Send Error] #{e.class}: #{e.message}"
  end

  def self.answer_callback_safely(bot, callback)
    return unless callback&.id

    bot.api.answer_callback_query(callback_query_id: callback.id)
  rescue StandardError => e
    warn "[Callback Answer Error] #{e.class}: #{e.message}"
  end

  def self.show_profile(bot, chat_id, user)
    role = user[:mode] || 'не выбран'
    name = user[:name] || 'не задано'
    safe_send(
      bot,
      chat_id,
      "Ваш профиль:\nИмя: #{name}\nРоль: #{role}\nTelegram ID: #{user[:telegram_id]}"
    )
  end

  def self.handle_mode_selection(message, bot, chat_id, user, text)
    case text
    when 'Я автор'
      # ВАЖНО: режим не ставим здесь, это делает AuthorFSM
      AuthorFSM.handle(message, bot, user)
    when 'Я ученик'
      # ВАЖНО: режим не ставим здесь, это делает StudentFSM
      StudentFSM.handle(message, bot, user)
    else
      safe_send(bot, chat_id, Messages::START, reply_markup: Keyboards.start_menu)
    end
  end
end

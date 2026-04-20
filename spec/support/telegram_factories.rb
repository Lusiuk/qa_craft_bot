# frozen_string_literal: true

require 'telegram/bot'

module TelegramFactories
  module_function

  def user(telegram_id:)
    Telegram::Bot::Types::User.new(
      id: telegram_id,
      is_bot: false,
      first_name: 'Test'
    )
  end

  def chat(chat_id:)
    Telegram::Bot::Types::Chat.new(
      id: chat_id,
      type: 'private'
    )
  end

  def message(text:, chat_id: 1001, telegram_id: 2002)
    Telegram::Bot::Types::Message.new(
      message_id: 1,
      chat: chat(chat_id:),
      from: user(telegram_id:),
      date: Time.now.to_i,
      text:
    )
  end

  def callback_query(data:, chat_id: 1001, telegram_id: 2002)
    msg = Telegram::Bot::Types::Message.new(
      message_id: 1,
      chat: chat(chat_id:),
      from: user(telegram_id:),
      date: Time.now.to_i,
      text: 'callback'
    )

    Telegram::Bot::Types::CallbackQuery.new(
      id: 'cbq-1',
      from: user(telegram_id:),
      message: msg,
      chat_instance: 'ci-1',
      data:
    )
  end
end

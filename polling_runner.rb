# frozen_string_literal: true

require 'telegram/bot'
require_relative 'app/bot_processor'

TOKEN = ENV.fetch('BOT_TOKEN', nil)

Telegram::Bot::Client.run(TOKEN) do |bot|
  bot.listen do |update|
    BotProcessor.call(update, bot)
  end
end

# frozen_string_literal: true

require 'dotenv/load'
require 'json'
require 'sinatra'
require 'telegram/bot'
require_relative 'app/bot_processor'

set :bind, '0.0.0.0'
set :port, ENV.fetch('PORT', 4567).to_i
set :environment, :development
set :show_exceptions, true

configure :development do
  set :host_authorization, {
    permitted_hosts: [
      '.ngrok-free.dev',
      '.ngrok.io',
      'localhost',
      '127.0.0.1'
    ]
  }
end

BOT_TOKEN = ENV.fetch('TELEGRAM_BOT_TOKEN') do
  raise 'TELEGRAM_BOT_TOKEN environment variable is required'
end

BOT = Telegram::Bot::Client.new(BOT_TOKEN)

post '/webhook' do
  content_type :json
  request.body.rewind

  begin
    payload = request.body.read
    data = JSON.parse(payload)
    update = Telegram::Bot::Types::Update.new(data)

    BotProcessor.call(update, BOT)

    status 200
    { ok: true }.to_json
  rescue JSON::ParserError => e
    warn "[Webhook JSON Error] #{e.class}: #{e.message}"
    status 200
    { ok: false, error: 'invalid_json' }.to_json
  rescue StandardError => e
    warn "[Webhook Error] #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    status 200
    { ok: false, error: 'internal_error' }.to_json
  end
end

get '/health' do
  content_type :json
  { ok: true, service: 'bot', mode: 'webhook' }.to_json
end

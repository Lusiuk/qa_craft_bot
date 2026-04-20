# frozen_string_literal: true

require 'dotenv/load'
require 'json'
require 'net/http'
require 'uri'

BOT_TOKEN = ENV.fetch('TELEGRAM_BOT_TOKEN') do
  raise 'TELEGRAM_BOT_TOKEN environment variable is required'
end

NGROK_API = ENV.fetch('NGROK_API', 'http://localhost:4040')

def http_get_json(url)
  uri = URI(url)
  response = Net::HTTP.get_response(uri)
  raise "GET #{url} failed: #{response.code} #{response.body}" unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body)
end

def http_post_form(url, params)
  uri = URI(url)
  req = Net::HTTP::Post.new(uri)
  req.set_form_data(params)

  Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
    res = http.request(req)
    JSON.parse(res.body)
  end
end

def get_ngrok_https_url
  data = http_get_json("#{NGROK_API}/api/tunnels")
  tunnel = data.fetch('tunnels', []).find { |t| t['proto'] == 'https' }
  tunnel && tunnel['public_url']
end

def set_webhook(base_url)
  url = "https://api.telegram.org/bot#{BOT_TOKEN}/setWebhook"
  http_post_form(url, { url: "#{base_url}/webhook", drop_pending_updates: true })
end

def get_webhook_info
  url = "https://api.telegram.org/bot#{BOT_TOKEN}/getWebhookInfo"
  http_get_json(url)
end

begin
  puts '⏳ Waiting ngrok tunnel...'
  sleep 2

  ngrok_url = nil
  30.times do
    ngrok_url = get_ngrok_https_url
    break if ngrok_url

    sleep 1
  end

  raise 'Не удалось получить HTTPS URL от ngrok' unless ngrok_url

  puts "🔗 Ngrok URL: #{ngrok_url}"

  result = set_webhook(ngrok_url)
  raise "setWebhook error: #{result['description']}" unless result['ok']

  puts "✅ Webhook установлен: #{ngrok_url}/webhook"

  info = get_webhook_info
  puts "ℹ️ Webhook info: #{info}"
rescue StandardError => e
  warn "❌ update_webhook failed: #{e.class}: #{e.message}"
  exit 1
end

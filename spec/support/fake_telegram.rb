# frozen_string_literal: true

class FakeBotApi
  attr_reader :sent

  def initialize
    @sent = []
  end

  def send_message(chat_id:, text:, reply_markup: nil)
    @sent << { chat_id:, text:, reply_markup: }
  end

  def last
    @sent.last
  end

  def answer_callback_query(*)
    # в тестах нам достаточно, что метод существует и не падает
    true
  end
end

class FakeBot
  attr_reader :api

  def initialize(api = FakeBotApi.new)
    @api = api
  end
end

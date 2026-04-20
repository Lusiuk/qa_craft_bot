# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../app/state_machines/author_fsm'

RSpec.describe 'Author flow: list my tests' do
  let(:api) { FakeBotApi.new }
  let(:bot) { FakeBot.new(api) }

  let(:chat_id) { 1001 }
  let(:telegram_id) { 2002 }
  let(:user) { { id: 1, telegram_id:, mode: 'author', name: nil } }

  let(:draft) { { id: 10, author_user_id: user[:id], state: 'idle' } }
  let(:session) { { id: 20, user_id: user[:id], pending_mode: nil, state: 'idle' } }

  before do
    allow(DraftRepo).to receive(:find_or_create).and_return(draft)
    allow(SessionRepo).to receive(:find_or_create).and_return(session)
    allow(DraftRepo).to receive(:update)
    allow(DraftRepo).to receive(:clear)

    allow(TestRepo).to receive(:by_author).and_return([
                                                        { id: 2, title: 'Тюремные шахматы',
                                                          description: 'Очень сложный тест', access_code: 'TEAO-4586' },
                                                        { id: 4, title: 'тест на иноагента', description: nil,
                                                          access_code: 'XVFF-6468' }
                                                      ])
  end

  it 'shows description under title when listing tests' do
    AuthorFSM.handle(TelegramFactories.message(text: 'Мои тесты', chat_id:, telegram_id:), bot, user)

    # первое сообщение — список
    list_msg = api.sent.find { |m| m[:text].include?('📚 Ваши тесты') }
    expect(list_msg).not_to be_nil

    text = list_msg[:text]
    expect(text).to include('2 — Тюремные шахматы')
    expect(text).to include('📝 Очень сложный тест')
    expect(text).to include('📋 Код: TEAO-4586')

    # у второго теста description=nil — строки 📝 быть не должно
    expect(text).to include('4 — тест на иноагента')
    expect(text).to include('📋 Код: XVFF-6468')
  end
end

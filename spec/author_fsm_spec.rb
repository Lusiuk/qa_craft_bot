# frozen_string_literal: true

require_relative '../app/state_machines/author_fsm'
require_relative '../app/messages'
require_relative '../app/keyboards'

RSpec.describe AuthorFSM do
  let(:api) { FakeBotApi.new }
  let(:bot) { FakeBot.new(api) }

  let(:chat_id) { 1001 }
  let(:telegram_id) { 2002 }

  it 'switches to author mode and shows author menu' do
    user = { id: 1, telegram_id:, mode: nil, name: nil }
    draft = { id: 20, author_user_id: 1, state: 'idle' }
    session = { id: 10, user_id: 1, state: 'idle', pending_mode: nil }

    allow(DraftRepo).to receive(:find_or_create).and_return(draft)
    allow(SessionRepo).to receive(:find_or_create).and_return(session)

    allow(UserRepo).to receive(:set_mode)
    allow(DraftRepo).to receive(:update)

    described_class.handle(
      TelegramFactories.message(text: 'Я автор', chat_id:, telegram_id:),
      bot,
      user
    )

    expect(UserRepo).to have_received(:set_mode).with(user[:id], 'author')
    expect(api.last[:text]).to include('Режим автора')
    expect(api.last[:reply_markup]).to respond_to(:keyboard)
  end

  it "handles 'Назад' in idle: clears mode and shows start menu" do
    user = { id: 1, telegram_id:, mode: 'author', name: nil }
    draft = { id: 20, author_user_id: 1, state: 'idle' }
    session = { id: 10, user_id: 1, state: 'idle', pending_mode: nil }

    allow(DraftRepo).to receive(:find_or_create).and_return(draft)
    allow(SessionRepo).to receive(:find_or_create).and_return(session)

    allow(UserRepo).to receive(:clear_mode)
    allow(DraftRepo).to receive(:update)
    allow(SessionRepo).to receive(:update)

    described_class.handle(
      TelegramFactories.message(text: 'Назад', chat_id:, telegram_id:),
      bot,
      user
    )

    expect(UserRepo).to have_received(:clear_mode).with(user[:id])
    expect(api.last[:text]).to include('Выберите вашу роль')
    expect(api.last[:reply_markup]).to respond_to(:keyboard)
  end
end

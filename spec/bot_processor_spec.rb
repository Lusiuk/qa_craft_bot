# frozen_string_literal: true

require_relative '../app/bot_processor'

RSpec.describe BotProcessor do
  let(:api) { FakeBotApi.new }
  let(:bot) { FakeBot.new(api) }

  let(:chat_id) { 1001 }
  let(:telegram_id) { 2002 }

  it 'handles /start: clears mode and shows start menu' do
    user = { id: 1, telegram_id:, mode: 'author', name: nil }

    allow(UserRepo).to receive(:find_or_create).and_return(user)
    allow(UserRepo).to receive(:clear_mode)

    described_class.call(TelegramFactories.message(text: '/start', chat_id:, telegram_id:), bot)

    expect(UserRepo).to have_received(:clear_mode).with(user[:id])
    expect(api.sent.size).to eq(1)
    expect(api.sent[0][:chat_id]).to eq(chat_id)
    expect(api.sent[0][:text]).to include('Привет')
    expect(api.sent[0][:reply_markup]).to respond_to(:keyboard)
  end

  it 'handles /whoami: prints profile' do
    user = { id: 1, telegram_id:, mode: 'student', name: 'Иван' }

    allow(UserRepo).to receive(:find_or_create).and_return(user)

    described_class.call(TelegramFactories.message(text: '/whoami', chat_id:, telegram_id:), bot)

    expect(api.sent.size).to eq(1)
    expect(api.sent[0][:text]).to include('Имя: Иван')
    expect(api.sent[0][:text]).to include('Роль: student')
    expect(api.sent[0][:text]).to include(telegram_id.to_s)
  end

  it 'routes to AuthorFSM only when mode=author' do
    user = { id: 1, telegram_id:, mode: 'author', name: nil }
    allow(UserRepo).to receive(:find_or_create).and_return(user)

    allow(AuthorFSM).to receive(:handle)
    allow(StudentFSM).to receive(:handle)

    described_class.call(TelegramFactories.message(text: 'Создать тест', chat_id:, telegram_id:),
                         bot)

    expect(AuthorFSM).to have_received(:handle)
    expect(StudentFSM).not_to have_received(:handle)
  end

  it 'routes to StudentFSM only when mode=student' do
    user = { id: 1, telegram_id:, mode: 'student', name: nil }
    allow(UserRepo).to receive(:find_or_create).and_return(user)

    allow(AuthorFSM).to receive(:handle)
    allow(StudentFSM).to receive(:handle)

    described_class.call(
      TelegramFactories.message(text: 'Ввести код доступа', chat_id:, telegram_id:), bot
    )

    expect(StudentFSM).to have_received(:handle)
    expect(AuthorFSM).not_to have_received(:handle)
  end

  it 'when mode=nil and text is unknown: shows start menu' do
    user = { id: 1, telegram_id:, mode: nil, name: nil }
    allow(UserRepo).to receive(:find_or_create).and_return(user)

    described_class.call(TelegramFactories.message(text: '???', chat_id:, telegram_id:), bot)

    expect(api.sent.size).to eq(1)
    expect(api.sent[0][:text]).to include('Привет')
    expect(api.sent[0][:reply_markup]).to respond_to(:keyboard)
  end

  it "when mode=nil and user presses 'Я автор': delegates to AuthorFSM" do
    user = { id: 1, telegram_id:, mode: nil, name: nil }
    allow(UserRepo).to receive(:find_or_create).and_return(user)

    allow(AuthorFSM).to receive(:handle)
    allow(StudentFSM).to receive(:handle)

    described_class.call(TelegramFactories.message(text: 'Я автор', chat_id:, telegram_id:), bot)

    expect(AuthorFSM).to have_received(:handle)
    expect(StudentFSM).not_to have_received(:handle)
  end

  it "when mode=nil and user presses 'Я ученик': delegates to StudentFSM" do
    user = { id: 1, telegram_id:, mode: nil, name: nil }
    allow(UserRepo).to receive(:find_or_create).and_return(user)

    allow(AuthorFSM).to receive(:handle)
    allow(StudentFSM).to receive(:handle)

    described_class.call(TelegramFactories.message(text: 'Я ученик', chat_id:, telegram_id:), bot)

    expect(StudentFSM).to have_received(:handle)
    expect(AuthorFSM).not_to have_received(:handle)
  end
end

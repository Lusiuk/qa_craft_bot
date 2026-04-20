# frozen_string_literal: true

require_relative '../app/state_machines/student_fsm'

RSpec.describe StudentFSM do
  let(:api) { FakeBotApi.new }
  let(:bot) { FakeBot.new(api) }

  let(:chat_id) { 1001 }
  let(:telegram_id) { 2002 }

  it 'switches to student mode from idle and shows student_start keyboard' do
    user = { id: 1, telegram_id:, mode: nil, name: nil }
    session = { id: 10, user_id: 1, state: 'idle', pending_mode: nil }

    allow(SessionRepo).to receive(:find_or_create).and_return(session)
    allow(SessionRepo).to receive(:update)
    allow(UserRepo).to receive(:set_mode)

    described_class.handle(
      TelegramFactories.message(text: 'Я ученик', chat_id:, telegram_id:),
      bot,
      user
    )

    expect(UserRepo).to have_received(:set_mode).with(user[:id], 'student')
    expect(SessionRepo).to have_received(:update).with(session[:id], hash_including(state: kind_of(String)))
    expect(api.last[:text]).to include('Выберите действие')
  end

  it "does not crash if user presses 'Я ученик' again while state=wait_for_change" do
    user = { id: 1, telegram_id:, mode: 'student', name: nil }
    session = { id: 10, user_id: 1, state: 'wait_for_change', pending_mode: nil }

    allow(SessionRepo).to receive(:find_or_create).and_return(session)
    allow(SessionRepo).to receive(:update)
    allow(UserRepo).to receive(:set_mode)

    expect do
      described_class.handle(
        TelegramFactories.message(text: 'Я ученик', chat_id:, telegram_id:),
        bot,
        user
      )
    end.not_to raise_error

    expect(api.last[:text]).to include('Выберите действие')
  end

  it "handles 'Назад' from wait_for_change -> goes to idle and shows main menu" do
    user = { id: 1, telegram_id:, mode: 'student', name: nil }
    session = { id: 10, user_id: 1, state: 'wait_for_change', pending_mode: nil }

    allow(SessionRepo).to receive(:find_or_create).and_return(session)
    allow(SessionRepo).to receive(:update)
    allow(UserRepo).to receive(:clear_mode)

    described_class.handle(
      TelegramFactories.message(text: 'Назад', chat_id:, telegram_id:),
      bot,
      user
    )

    expect(UserRepo).to have_received(:clear_mode).with(user[:id])
    expect(api.last[:text]).to include('Выберите вашу роль')
  end
end

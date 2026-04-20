# frozen_string_literal: true

# spec/flows/author_creates_test_spec.rb
require_relative '../spec_helper'
require_relative '../../app/state_machines/author_fsm'
require_relative '../../app/keyboards'

RSpec.describe 'Author flow: create test' do
  let(:api) { FakeBotApi.new }
  let(:bot) { FakeBot.new(api) }

  let(:chat_id) { 1001 }
  let(:telegram_id) { 2002 }
  let(:user) { { id: 1, telegram_id:, mode: 'author', name: nil } }

  let(:draft) do
    {
      id: 10,
      author_user_id: user[:id],
      state: 'idle',
      target_test_id: nil,
      draft_title: nil,
      draft_description: nil,
      draft_question_text: nil,
      draft_options_json: nil
    }
  end

  let(:session) { { id: 20, user_id: user[:id], pending_mode: nil, state: 'idle' } }

  before do
    allow(DraftRepo).to receive(:find_or_create).and_return(draft)
    allow(SessionRepo).to receive(:find_or_create).and_return(session)

    allow(DraftRepo).to receive(:update) { |_, attrs| draft.merge!(attrs) }
    allow(DraftRepo).to receive(:clear) { |id| draft.clear.merge!(id:) }

    allow(UserRepo).to receive(:set_mode)
    allow(UserRepo).to receive(:clear_mode)

    allow(SessionRepo).to receive(:update)

    # создание сущностей теста
    allow(AccessCodeGenerator).to receive(:generate).and_return('CODE123')
    allow(TestRepo).to receive(:create).and_return(777)
    allow(QuestionRepo).to receive(:by_test).and_return([]) # до первого вопроса
    allow(QuestionRepo).to receive(:create).and_return(888)
    allow(OptionRepo).to receive(:create_many)
  end

  it 'creates a test and first question' do
    # 1) Начать создание
    AuthorFSM.handle(TelegramFactories.message(text: 'Создать тест', chat_id:, telegram_id:), bot,
                     user)
    expect(api.last[:text]).to include('Введите название')
    expect(draft[:state]).to eq('waiting_title')

    # 2) Ввести title
    AuthorFSM.handle(TelegramFactories.message(text: 'Мой тест', chat_id:, telegram_id:), bot, user)
    expect(api.last[:text]).to include('Введите описание')
    expect(draft[:draft_title]).to eq('Мой тест')
    expect(draft[:state]).to eq('waiting_description')

    # 3) Ввести description
    AuthorFSM.handle(TelegramFactories.message(text: 'Описание', chat_id:, telegram_id:), bot, user)
    expect(api.last[:text]).to include('Введите текст первого вопроса')
    expect(draft[:draft_description]).to eq('Описание')
    expect(draft[:state]).to eq('waiting_question_text')

    # 4) Ввести вопрос
    AuthorFSM.handle(TelegramFactories.message(text: '2+2?', chat_id:, telegram_id:), bot, user)
    expect(api.last[:text]).to include('Введите варианты ответов')
    expect(draft[:draft_question_text]).to eq('2+2?')
    expect(draft[:state]).to eq('waiting_options')

    # 5) Ввести варианты
    AuthorFSM.handle(TelegramFactories.message(text: "3\n4\n5", chat_id:, telegram_id:), bot, user)
    expect(api.last[:text]).to include('Введите номер правильного варианта')
    expect(draft[:state]).to eq('waiting_correct')
    expect(draft[:draft_options_json]).to include('3')
    expect(draft[:draft_options_json]).to include('4')

    # 6) Выбрать правильный вариант (2 => "4") → создаётся тест + вопрос + опции
    AuthorFSM.handle(TelegramFactories.message(text: '2', chat_id:, telegram_id:), bot, user)

    expect(AccessCodeGenerator).to have_received(:generate)
    expect(TestRepo).to have_received(:create).with(hash_including(
                                                      author_id: user[:id],
                                                      title: 'Мой тест',
                                                      description: 'Описание',
                                                      access_code: 'CODE123'
                                                    ))

    expect(QuestionRepo).to have_received(:create).with(hash_including(
                                                          test_id: 777,
                                                          position: 1,
                                                          text: '2+2?'
                                                        ))

    expect(OptionRepo).to have_received(:create_many).with(hash_including(
                                                             question_id: 888,
                                                             correct_index: 1
                                                           ))

    # Сообщения: сначала "Тест создан + код", потом "Вопрос добавлен"
    all_texts = api.sent.map { |m| m[:text] }.join("\n")
    expect(all_texts).to include('Тест создан')
    expect(all_texts).to include('Код доступа: CODE123')
    expect(all_texts).to include('Вопрос добавлен')
  end
end

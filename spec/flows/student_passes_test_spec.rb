# frozen_string_literal: true

# spec/flows/student_passes_test_spec.rb
require_relative '../spec_helper'
require_relative '../../app/state_machines/student_fsm'

RSpec.describe 'Student flow: pass test' do
  let(:api) { FakeBotApi.new }
  let(:bot) { FakeBot.new(api) }

  let(:chat_id) { 1001 }
  let(:telegram_id) { 2002 }
  let(:user) { { id: 1, telegram_id:, mode: 'student', name: 'Петя' } }

  let(:session) do
    {
      id: 10,
      user_id: user[:id],
      state: 'waiting_code',
      pending_mode: nil,
      test_id: nil,
      current_question_pos: 1,
      correct_count: 0,
      started_at: nil
    }
  end

  let(:test) { { id: 777, author_user_id: 99, title: 'Фейк тест', description: 'Описание', access_code: 'CODE123' } }
  let(:author) { { id: 99, telegram_id: 5555, mode: 'author', name: 'Автор' } }

  let(:q1) { { id: 1, test_id: test[:id], position: 1, text: '2+2?' } }
  let(:q2) { { id: 2, test_id: test[:id], position: 2, text: '3+3?' } }

  let(:q1_opts) do
    [
      { id: 11, question_id: q1[:id], text: '3', is_correct: false },
      { id: 12, question_id: q1[:id], text: '4', is_correct: true }
    ]
  end

  let(:q2_opts) do
    [
      { id: 21, question_id: q2[:id], text: '5', is_correct: false },
      { id: 22, question_id: q2[:id], text: '6', is_correct: true }
    ]
  end

  before do
    # FSM создаёт SessionRepo.find_or_create в .handle
    allow(SessionRepo).to receive(:find_or_create).and_return(session)

    # update будет меня��ь session "как будто БД"
    allow(SessionRepo).to receive(:update) do |_, attrs|
      session.merge!(attrs)
    end

    allow(SessionRepo).to receive(:find_by_id).and_return(session)

    allow(TestRepo).to receive(:find_by_code).with('CODE123').and_return(test)
    allow(TestRepo).to receive(:find_by_id).with(test[:id]).and_return(test)

    allow(QuestionRepo).to receive(:by_test).with(test[:id]).and_return([q1, q2])

    allow(OptionRepo).to receive(:by_question) do |qid|
      qid == q1[:id] ? q1_opts : q2_opts
    end

    allow(OptionRepo).to receive(:find_by_id) do |oid|
      (q1_opts + q2_opts).find { |o| o[:id] == oid }
    end

    allow(AttemptRepo).to receive(:create)
    allow(UserRepo).to receive(:find_by_id).with(test[:author_user_id]).and_return(author)
  end

  it 'enters code, starts test, answers questions, completes and creates attempt' do
    # 1) Ввести код доступа (мы стартуем со state waiting_code)
    StudentFSM.handle(TelegramFactories.message(text: 'CODE123', chat_id:, telegram_id:), bot, user)

    all_texts = api.sent.map { |m| m[:text] }.join("\n")
    expect(all_texts).to include('Код найден')
    expect(all_texts).to include("Тест: #{test[:title]}")
    expect(all_texts).to include("Нажмите 'Начать'")

    expect(session[:state]).to eq('ready')
    expect(session[:test_id]).to eq(test[:id])
    expect(session[:current_question_pos]).to eq(1)
    expect(session[:correct_count]).to eq(0)
    expect(session[:started_at]).not_to be_nil

    # 2) Нажать "Начать" → показать вопрос 1 с inline кнопками
    StudentFSM.handle(TelegramFactories.message(text: 'Начать', chat_id:, telegram_id:), bot, user)

    last = api.last
    expect(last[:text]).to include('Вопрос 1/2')
    expect(last[:text]).to include(q1[:text])
    expect(last[:reply_markup]).to be_a(Telegram::Bot::Types::InlineKeyboardMarkup)
    expect(session[:state]).to eq('waiting_answer')

    # 3) Ответить на 1 вопрос правильно (option_id=12)
    StudentFSM.handle(
      TelegramFactories.callback_query(data: "answer:#{q1[:id]}:12", chat_id:, telegram_id:), bot, user
    )

    expect(session[:correct_count]).to eq(1)
    expect(session[:current_question_pos]).to eq(2)
    expect(api.last[:text]).to include('Вопрос 2/2')

    # 4) Ответить на 2 вопрос правильно (option_id=22) → завершение
    StudentFSM.handle(
      TelegramFactories.callback_query(data: "answer:#{q2[:id]}:22", chat_id:, telegram_id:), bot, user
    )

    expect(session[:state]).to eq('finished')

    # Было 2 send_message: автору и ученику
    texts = api.sent.map { |m| m[:text] }.join("\n")
    expect(texts).to include('Тест завершён') # автору
    expect(texts).to include('Тест завершён!') # ученику

    expect(AttemptRepo).to have_received(:create).with(hash_including(
                                                         test_id: test[:id],
                                                         student_user_id: user[:id],
                                                         correct_count: 2,
                                                         total_count: 2
                                                       ))
  end
end

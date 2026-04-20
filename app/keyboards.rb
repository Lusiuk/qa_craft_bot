# frozen_string_literal: true

require 'telegram/bot'

class Keyboards
  def self.start_menu
    Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: [
        [Telegram::Bot::Types::KeyboardButton.new(text: 'Я автор')],
        [Telegram::Bot::Types::KeyboardButton.new(text: 'Я ученик')]
      ],
      resize_keyboard: true
    )
  end

  def self.author_menu
    Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: [
        [Telegram::Bot::Types::KeyboardButton.new(text: 'Создать тест')],
        [Telegram::Bot::Types::KeyboardButton.new(text: 'Мои тесты')],
        [Telegram::Bot::Types::KeyboardButton.new(text: 'Назад')]
      ],
      resize_keyboard: true
    )
  end

  def self.student_start
    Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: [
        [Telegram::Bot::Types::KeyboardButton.new(text: 'Задать имя пользователя')],
        [Telegram::Bot::Types::KeyboardButton.new(text: 'Ввести код доступа')],
        [Telegram::Bot::Types::KeyboardButton.new(text: 'Назад')]
      ],
      resize_keyboard: true
    )
  end

  def self.back_button
    Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: [
        [Telegram::Bot::Types::KeyboardButton.new(text: 'Назад')]
      ],
      resize_keyboard: true
    )
  end

  def self.next_question_menu
    Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: [
        [Telegram::Bot::Types::KeyboardButton.new(text: 'Добавить вопрос')],
        [Telegram::Bot::Types::KeyboardButton.new(text: 'Завершить')]
      ],
      resize_keyboard: true
    )
  end

  def self.start_test_menu
    Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: [
        [Telegram::Bot::Types::KeyboardButton.new(text: 'Начать')],
        [Telegram::Bot::Types::KeyboardButton.new(text: 'Назад')]
      ],
      resize_keyboard: true
    )
  end

  def self.finish_menu
    Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: [
        [Telegram::Bot::Types::KeyboardButton.new(text: 'Пройти заново')],
        [Telegram::Bot::Types::KeyboardButton.new(text: 'Выйти')]
      ],
      resize_keyboard: true
    )
  end

  def self.edit_menu
    Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: [
        [Telegram::Bot::Types::KeyboardButton.new(text: 'Редактировать тест')],
        [Telegram::Bot::Types::KeyboardButton.new(text: 'Удалить тест')],
        [Telegram::Bot::Types::KeyboardButton.new(text: 'Назад')]
      ],
      resize_keyboard: true
    )
  end

  def self.editing_test_menu
    Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: [
        [Telegram::Bot::Types::KeyboardButton.new(text: 'Редактировать название')],
        [Telegram::Bot::Types::KeyboardButton.new(text: 'Редактировать описание')],
        [Telegram::Bot::Types::KeyboardButton.new(text: 'Редактировать вопросы')],
        [Telegram::Bot::Types::KeyboardButton.new(text: 'Назад')]
      ],
      resize_keyboard: true
    )
  end

  def self.confirm_delete_menu
    Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: [
        [Telegram::Bot::Types::KeyboardButton.new(text: 'Удалить'),
         Telegram::Bot::Types::KeyboardButton.new(text: 'Отмена')]
      ],
      resize_keyboard: true
    )
  end

  def self.confirm_change_mode
    Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: [
        [Telegram::Bot::Types::KeyboardButton.new(text: 'Да'), Telegram::Bot::Types::KeyboardButton.new(text: 'Нет')]
      ],
      resize_keyboard: true
    )
  end
end

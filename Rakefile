# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task' # 1. Добавляем библиотеку задач RuboCop

RSpec::Core::RakeTask.new(:spec)

# 2. Описываем задачу для RuboCop
RuboCop::RakeTask.new(:rubocop) do |task|
  # task.requires << 'rubocop-rspec' # Раскомментируйте, если используете расширения
  task.options = ['--display-cop-names', '--extra-details']
  task.fail_on_error = true # Rake упадет с ошибкой, если стиль нарушен
end

# 3. Обновляем задачу по умолчанию
# Теперь при запуске `bundle exec rake` сначала выполнится RuboCop, а затем тесты
task default: %i[rubocop spec]

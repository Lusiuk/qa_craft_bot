# frozen_string_literal: true

require_relative 'version'

Gem::Specification.new do |spec|
  spec.name = 'qa_craft_bot'
  spec.version = QACraftBot::VERSION
  spec.authors = ['Lusiuk']
  spec.email = ['brcloud1@yandex.ru']

  spec.summary = 'Telegram-бот для создания и прохождения закрытых тестов с уведомлениями'
  spec.description = 'QA Craft Bot - Telegram-бот для авторов тестов и их учеников: создание приватных тестов с доступом по коду, их прохождение, результаты и уведомления преподавателю. Поддерживает хранение в SQLite и расширяемую логику на AASM.'
  spec.homepage = 'https://github.com/Lusiuk/qa_craft_bot'
  spec.required_ruby_version = '>= 3.2.0'
  spec.metadata['allowed_push_host'] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) || f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/])
    end
  end

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # --- Runtime dependencies ---
  spec.add_dependency "telegram-bot-ruby"
  spec.add_dependency "aasm"
  spec.add_dependency 'json', '~> 2.0'
  spec.add_dependency "sqlite3"
  spec.add_dependency "sequel"
  spec.add_dependency "sinatra"

  # --- Development dependencies ---
  spec.add_development_dependency 'base64'
  spec.add_development_dependency 'benchmark'
  spec.add_development_dependency 'irb'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 1.50.0'
  spec.add_development_dependency 'rubocop-performance', '~> 1.16'
  spec.add_development_dependency 'rubocop-rspec', '~> 1.16'
  spec.add_development_dependency 'simplecov', '~> 0.21.0'
end
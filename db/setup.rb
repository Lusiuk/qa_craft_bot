# frozen_string_literal: true

require 'sequel'

DB = Sequel.sqlite('db/db.sqlite3')

DB.create_table? :users do
  primary_key :id
  Integer :telegram_id, null: false, unique: true
  String :name
  String :mode # "author" | "student" | nil
end

DB.create_table? :tests do
  primary_key :id
  Integer :author_user_id, null: false
  String :title, null: false
  String :description
  String :access_code, null: false, unique: true
  DateTime :deleted_at
end

DB.create_table? :questions do
  primary_key :id
  Integer :test_id, null: false
  Integer :position, null: false
  String :text, null: false
end

DB.create_table? :options do
  primary_key :id
  Integer :question_id, null: false
  Integer :position, null: false
  String :text, null: false
  TrueClass :is_correct, default: false
end

DB.create_table? :sessions do
  primary_key :id
  Integer :user_id, null: false
  Integer :test_id
  String :state, null: false
  Integer :current_question_pos, default: 1
  Integer :correct_count, default: 0
  DateTime :started_at
  String :pending_mode
end

DB.create_table? :drafts do
  primary_key :id
  Integer :author_user_id, null: false
  String :state, null: false
  Integer :target_test_id
  Integer :edit_question_pos
  String :draft_title
  String :draft_description
  String :draft_question_text
  String :draft_options_json
end

DB.create_table? :attempts do
  primary_key :id
  Integer :test_id, null: false
  Integer :student_user_id, null: false
  String  :student_name
  Integer :correct_count, null: false
  Integer :total_count, null: false
  DateTime :started_at, null: false
  DateTime :finished_at, null: false
  Integer :duration_sec, null: false
end

puts 'DB setup done'

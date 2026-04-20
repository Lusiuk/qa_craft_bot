# frozen_string_literal: true

require_relative '../db/connection'

class OptionRepo
  def self.create_many(question_id:, options:, correct_index:)
    options.each_with_index do |text, idx|
      DB[:options].insert(
        question_id:,
        position: idx + 1,
        text:,
        is_correct: (idx == correct_index)
      )
    end
  end

  def self.by_question(question_id)
    DB[:options].where(question_id:).order(:position).all
  end

  def self.delete_by_question(question_id)
    DB[:options].where(question_id:).delete
  end

  def self.find_by_id(id)
    DB[:options].where(id:).first
  end
end

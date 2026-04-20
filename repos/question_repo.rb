# frozen_string_literal: true

require_relative '../db/connection'

class QuestionRepo
  def self.create(test_id:, position:, text:)
    DB[:questions].insert(test_id:, position:, text:)
  end

  def self.by_test(test_id)
    DB[:questions].where(test_id:).order(:position).all
  end

  def self.find_by_test_and_pos(test_id, pos)
    DB[:questions].where(test_id:, position: pos).first
  end

  def self.update_text(question_id, text)
    DB[:questions].where(id: question_id).update(text:)
  end

  def self.delete_by_test(test_id)
    DB[:questions].where(test_id:).delete
  end
end

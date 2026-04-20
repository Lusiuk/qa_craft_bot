# frozen_string_literal: true

require_relative '../db/connection'

class AttemptRepo
  def self.create(test_id:, student_user_id:, student_name:, correct_count:, total_count:, started_at:, finished_at:, duration_sec:)
    DB[:attempts].insert(
      test_id:,
      student_user_id:,
      student_name:,
      correct_count:,
      total_count:,
      started_at:,
      finished_at:,
      duration_sec:
    )
  end
end

# frozen_string_literal: true

require_relative '../db/connection'

class SessionRepo
  def self.find_or_create(user_id)
    s = DB[:sessions].where(user_id:).first
    return s if s

    id = DB[:sessions].insert(user_id:, state: 'idle', current_question_pos: 1, correct_count: 0)
    DB[:sessions].where(id:).first
  end

  def self.update(session_id, attrs)
    DB[:sessions].where(id: session_id).update(attrs)
  end

  def self.find_by_id(id)
    DB[:sessions].where(id:).first
  end
end

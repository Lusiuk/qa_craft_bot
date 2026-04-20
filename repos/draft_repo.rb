# frozen_string_literal: true

require_relative '../db/connection'

class DraftRepo
  def self.find_or_create(author_id)
    d = DB[:drafts].where(author_user_id: author_id).first
    return d if d

    id = DB[:drafts].insert(author_user_id: author_id, state: 'idle')
    DB[:drafts].where(id:).first
  end

  def self.update(draft_id, attrs)
    DB[:drafts].where(id: draft_id).update(attrs)
  end

  def self.clear(draft_id)
    DB[:drafts].where(id: draft_id).update(
      state: 'idle',
      target_test_id: nil,
      edit_question_pos: nil,
      draft_title: nil,
      draft_description: nil,
      draft_question_text: nil,
      draft_options_json: nil
    )
  end
end

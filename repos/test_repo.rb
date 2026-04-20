# frozen_string_literal: true

require_relative '../db/connection'

class TestRepo
  def self.create(author_id:, title:, description:, access_code:)
    DB[:tests].insert(
      author_user_id: author_id,
      title:,
      description:,
      access_code:,
      deleted_at: nil
    )
  end

  def self.find_by_code(code)
    DB[:tests].where(access_code: code, deleted_at: nil).first
  end

  def self.by_author(author_id)
    DB[:tests].where(author_user_id: author_id, deleted_at: nil).all
  end

  def self.find_by_id(id)
    DB[:tests].where(id:, deleted_at: nil).first
  end

  def self.soft_delete(test_id, author_id)
    DB[:tests].where(id: test_id, author_user_id: author_id).update(deleted_at: Time.now)
  end

  def self.update_title(test_id, author_id, new_title)
    DB[:tests].where(id: test_id, author_user_id: author_id).update(title: new_title)
  end

  def self.update_description(test_id, author_id, new_desc)
    DB[:tests].where(id: test_id, author_user_id: author_id).update(description: new_desc)
  end
end

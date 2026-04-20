# frozen_string_literal: true

require_relative '../db/connection'

class UserRepo
  def self.find_or_create(telegram_id)
    user = DB[:users].where(telegram_id:).first
    return user if user

    id = DB[:users].insert(telegram_id:)
    DB[:users].where(id:).first
  end

  def self.find_by_id(id)
    DB[:users].where(id:).first
  end

  def self.update_name(user_id, name)
    DB[:users].where(id: user_id).update(name:)
  end

  def self.set_mode(user_id, mode)
    DB[:users].where(id: user_id).update(mode:)
  end

  def self.clear_mode(user_id)
    DB[:users].where(id: user_id).update(mode: nil)
  end
end

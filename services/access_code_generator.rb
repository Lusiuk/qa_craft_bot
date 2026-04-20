# frozen_string_literal: true

class AccessCodeGenerator
  def self.generate
    letters = ('A'..'Z').to_a.sample(4).join
    digits  = rand(1000..9999)
    "#{letters}-#{digits}"
  end
end

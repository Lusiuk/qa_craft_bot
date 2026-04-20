# frozen_string_literal: true

require_relative '../repos/question_repo'
require_relative '../repos/option_repo'

class TestEditor
  def self.replace_question(test_id:, position:, new_text:, new_options:, correct_index:)
    q = QuestionRepo.find_by_test_and_pos(test_id, position)
    return false unless q

    QuestionRepo.update_text(q[:id], new_text)
    OptionRepo.delete_by_question(q[:id])
    OptionRepo.create_many(question_id: q[:id], options: new_options, correct_index:)
    true
  end
end

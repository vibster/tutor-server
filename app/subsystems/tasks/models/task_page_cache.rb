class Tasks::Models::TaskPageCache < ApplicationRecord
  belongs_to :task
  belongs_to :student, subsystem: :course_membership
  belongs_to :page,    subsystem: :content

  validates :task,    presence: true,
                      uniqueness: { scope: [ :course_membership_student_id, :content_page_id ] }
  validates :student, presence: true
  validates :page,    presence: true

  validates :num_assigned_exercises,  presence: true, numericality: { only_integer: true }
  validates :num_completed_exercises, presence: true, numericality: { only_integer: true }
  validates :num_correct_exercises,   presence: true, numericality: { only_integer: true }
end

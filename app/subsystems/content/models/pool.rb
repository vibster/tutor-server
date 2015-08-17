class Content::Models::Pool < Tutor::SubSystems::BaseModel

  wrapped_by ::Content::Strategies::Direct::Pool

  belongs_to :ecosystem, inverse_of: :pools

  enum pool_type: [
    :reading_dynamic, :reading_try_another, :homework_core, :homework_dynamic, :practice_widget
  ]

  serialize :content_exercise_ids, Array

  validates :ecosystem, presence: true
  validates :pool_type, presence: true
  validates :uuid, uniqueness: { allow_nil: true }

  def exercises
    Content::Models::Exercise.where(id: content_exercise_ids)
  end

end
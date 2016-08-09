class Forum::Models::Post < Tutor::SubSystems::BaseModel
  has_many :comment, subsystem: :forum, dependent: :destroy
  belongs_to :role, subsystem: :entity
  belongs_to :page, subsystem: :content
  belongs_to :exercise, subsystem: :content

  # :title, :content
end

class Forum::Models::Post < Tutor::SubSystems::BaseModel
  belongs_to :role, subsystem: :entity
  belongs_to :page, subsystem: :content
  belongs_to :exercise, subsystem: :content

  # :title, :content
end

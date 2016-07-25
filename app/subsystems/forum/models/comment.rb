class Forum::Models::Comment < Tutor::SubSystems::BaseModel
  belongs_to :role, subsystem: :entity
  # :title, :endorsed_at
end

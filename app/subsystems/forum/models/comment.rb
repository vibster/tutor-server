class Forum::Models::Comment < Tutor::SubSystems::BaseModel
  belongs_to :role, subsystem: :entity
  belongs_to :post, subsystem: :forum
  # :title, :endorsed_at

  def author_name
    role.role_user.profile.name
  end
end

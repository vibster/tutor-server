class Content::Models::Exercise < Tutor::SubSystems::BaseModel

  acts_as_resource

  wrapped_by ::Ecosystem::Strategies::Direct::Exercise

  belongs_to :page, inverse_of: :exercises
  has_one :chapter, through: :page
  has_one :book, through: :chapter
  has_one :ecosystem, through: :book

  has_many :exercise_tags, dependent: :destroy, autosave: true, inverse_of: :exercise
  has_many :tags, through: :exercise_tags

  has_many :tasked_exercises, subsystem: :tasks, dependent: :destroy, inverse_of: :exercise

  validates :number, presence: true
  validates :version, presence: true, uniqueness: { scope: :number }

  # http://stackoverflow.com/a/7745635
  scope :latest, ->(scope = unscoped) {
    joins{ scope.as(:later_version).on{ (later_version.number == ~number) & \
                                        (later_version.version > ~version) }.outer }
      .where{later_version.id == nil}
  }

  def uid
    "#{number}@#{version}"
  end

  def los
    tags.to_a.select(&:lo?)
  end

  def aplos
    tags.to_a.select(&:aplo?)
  end

end

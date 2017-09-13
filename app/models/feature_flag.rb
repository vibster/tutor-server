class FeatureFlag < ActiveRecord::Base

  enum name: [
    :is_lms_enabling_allowed
  ]

  belongs_to :course, class_name: 'CourseProfile::Models::Course'

  validate :has_one_scope
  validates :course_profile_course_id, uniqueness: { scope: :name }, allow_blank: true

  DEFAULTS = {
    is_lms_enabling_allowed: false
  }

  ACCEPTS_COURSE_SETTING = [
    :is_lms_enabling_allowed
  ]

  def self.initialize_globals!
    FeatureFlag.transaction do
      names.keys.each do |name|
        value = DEFAULTS[name.to_sym]
        raise("No default value for feature flag '#{name}'") if value.nil?
        FeatureFlag.find_or_create_by!(name: name, value: value, is_global: true)
      end
    end
  end

  def self.is_lms_enabling_allowed?(course_or_id:)
    override_by_course(name: :is_lms_enabling_allowed, course_or_id: course_or_id)
    # course_id == course_or_id.is_a?(Integer) ? course_or_id : course.id
    # effective_feature_flag =
    #   is_lms_enabling_allowed
    #   .where{
    #     (course_profile_course_id == course_id) |
    #     (is_global == true)
    #   }
    #   .order{course_profile_course_id.asc}
    #   .first

    # raise(FeatureFlagMissing, "is_lms_enabling_allowed: #{course_id}") if effective_feature_flag.nil?

    # effective_feature_flag.value
  end

  def self.globals
    where(is_global: true).each_with_object({}) {|ff, hash| hash[ff.name.to_sym] = ff.value}
  end

  protected

  def self.override_by_course(name:, course_or_id:)
    name = name.to_sym
    course_id == course_or_id.is_a?(Integer) ? course_or_id : course.id

    effective_feature_flag =
      self.send(name)
      .where{
        (course_profile_course_id == course_id) |
        (is_global == true)
      }
      .order{course_profile_course_id.asc}
      .first

    effective_feature_flag.try(:value) ||
    DEFAULTS[name] ||
    raise(FeatureFlagMissing, "#{name}: #{course_id}")
  end

  def has_one_scope
    number_of_scopes = 0

    number_of_scopes += 1 if is_global
    number_of_scopes += 1 if course_profile_course_id.present?

    errors.add(:base, "Must have either global or course scope") if number_of_scopes != 1
    errors.none?
  end

end

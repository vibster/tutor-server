require 'rails_helper'

RSpec.describe CourseProfile::Models::Course, type: :model do
  subject(:course) { FactoryBot.create :course_profile_course }

  it { is_expected.to belong_to(:time_zone).autosave(true) }

  it { is_expected.to belong_to(:school) }
  it { is_expected.to belong_to(:offering) }

  it { is_expected.to belong_to(:cloned_from) }

  it { is_expected.to have_many(:periods).dependent(:destroy) }
  it { is_expected.to have_many(:teachers).dependent(:destroy) }
  it { is_expected.to have_many(:students).dependent(:destroy) }

  it { is_expected.to have_many(:course_ecosystems) }
  it { is_expected.to have_many(:ecosystems) }

  it { is_expected.to have_many(:course_assistants) }

  it { is_expected.to have_many(:taskings) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:term) }
  it { is_expected.to validate_presence_of(:year) }
  it { is_expected.to validate_presence_of(:biglearn_student_clues_algorithm_name) }
  it { is_expected.to validate_presence_of(:biglearn_teacher_clues_algorithm_name) }
  it { is_expected.to validate_presence_of(:biglearn_assignment_spes_algorithm_name) }
  it { is_expected.to validate_presence_of(:biglearn_assignment_pes_algorithm_name) }
  it { is_expected.to validate_presence_of(:biglearn_practice_worst_areas_algorithm_name) }

  it { is_expected.to validate_uniqueness_of(:time_zone) }

  it do
    is_expected.to(
      validate_numericality_of(:homework_score_weight).is_greater_than_or_equal_to(0)
                                                      .is_less_than_or_equal_to(1)
    )
  end
  it do
    is_expected.to(
      validate_numericality_of(:homework_progress_weight).is_greater_than_or_equal_to(0)
                                                         .is_less_than_or_equal_to(1)
    )
  end
  it do
    is_expected.to(
      validate_numericality_of(:reading_score_weight).is_greater_than_or_equal_to(0)
                                                     .is_less_than_or_equal_to(1)
    )
  end
  it do
    is_expected.to(
      validate_numericality_of(:reading_progress_weight).is_greater_than_or_equal_to(0)
                                                        .is_less_than_or_equal_to(1)
    )
  end

  it 'validates format of default times' do
    course.default_open_time = '16:32'
    expect(course).to be_valid

    course.default_due_time = '16:'
    expect(course).not_to be_valid

    course.default_open_time = '24:00'
    expect(course).not_to be_valid

    course.default_due_time = '23:60'
    expect(course).not_to be_valid
  end

  it 'knows if it is deletable' do
    expect(course).to be_deletable

    user = FactoryBot.create :user
    period = FactoryBot.create(:course_membership_period, course: course)

    expect(course.reload).not_to be_deletable

    student = AddUserAsPeriodStudent[user: user, period: period].student

    expect(course.reload).not_to be_deletable

    student.destroy

    expect(course.reload).not_to be_deletable

    period.destroy

    expect(course.reload).to be_deletable

    teacher = AddUserAsCourseTeacher[user: user, course: course].teacher
    expect(course.reload).not_to be_deletable
    teacher.destroy
    expect(course.reload).to be_deletable
  end

  it 'knows if it has started' do
    expect(course).to be_started

    course.starts_at = Time.current.tomorrow
    expect(course).not_to be_started

    course.starts_at = Time.current - 1.week
    expect(course).to be_started
  end

  it 'knows if it has ended' do
    expect(course).not_to be_ended

    course.ends_at = Time.current.yesterday
    expect(course).to be_ended

    course.ends_at = Time.current + 1.week
    expect(course).not_to be_ended
  end

  it 'can get non-ended courses' do
    described_class.destroy_all
    a = FactoryBot.create :course_profile_course, ends_at: 1.day.ago
    b = FactoryBot.create :course_profile_course, ends_at: 1.day.from_now

    expect(described_class.not_ended.to_a).to eq [b]

    # Make sure `not_ended` scope evaluates Time.now on each call
    Timecop.freeze(2.days.ago) do
      expect(described_class.not_ended.to_a).to contain_exactly(a,b)
    end
  end

  it 'knows if it is active' do
    expect(course).to be_active

    course.starts_at = Time.current.tomorrow
    expect(course).not_to be_active

    course.starts_at = Time.current - 1.week
    course.ends_at = Time.current.yesterday
    expect(course).not_to be_active

    course.ends_at = Time.current + 1.week
    expect(course).to be_active
  end

  it 'cannot end before it starts' do
    expect(course).to be_valid

    course.starts_at = Time.current.tomorrow
    course.ends_at = Time.current.yesterday

    expect(course).not_to be_valid
  end

  it 'cannot be too far in the past or future' do
    expect(course).to be_valid

    course.year = CourseProfile::Models::Course::MIN_YEAR - 1
    expect(course).not_to be_valid

    course.year = Time.current.year + CourseProfile::Models::Course::MAX_FUTURE_YEARS + 1
    expect(course).not_to be_valid
  end

  it 'automatically sets starts_at and ends_at based on the term and year' do
    year = Time.current.year
    course.term = 'fall'
    course.year = year
    course.starts_at = nil
    course.ends_at = nil
    expect(course).to be_valid
    term_year = TermYear.new('fall', year)
    expect(course.starts_at).to eq term_year.starts_at
    expect(course.ends_at).to eq term_year.ends_at

    course.term = 'winter'
    course.year = year + 1
    course.starts_at = nil
    course.ends_at = nil
    expect(course).to be_valid
    term_year = TermYear.new('winter', year + 1)
    expect(course.starts_at).to eq term_year.starts_at
    expect(course.ends_at).to eq term_year.ends_at
  end

  context 'when is_lms_enabling_allowed is false' do
    before(:each) { course.update_column(:is_lms_enabling_allowed, false) }

    it 'can change is_lms_enabled from true to false' do
      course.update_column(:is_lms_enabled, true)
      expect(course.update_attributes(is_lms_enabled: false)).to eq true
    end

    it 'cannot change is_lms_enabled from false to true' do
      course.update_column(:is_lms_enabled, false)
      expect(course.update_attributes(is_lms_enabled: true)).to eq false
    end
  end

  it 'prevents is_lms_enabled from changing when is_access_switchable false' do
    course.update_column(:is_access_switchable, false)

    course.update_column(:is_lms_enabled, true)
    expect(course.update_attributes(is_lms_enabled: false)).to eq false

    course.update_column(:is_lms_enabled, false)
    expect(course.reload.update_attributes(is_lms_enabled: true)).to eq false
  end
end

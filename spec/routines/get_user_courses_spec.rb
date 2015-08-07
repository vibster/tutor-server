require 'rails_helper'

RSpec.describe GetUserCourses, :type => :routine do

  it 'gets courses, not duped' do
    user   = Entity::User.create!
    course = Entity::Course.create!
    period = CreatePeriod[course: course]

    AddUserAsCourseTeacher[user: user, course: course]
    AddUserAsPeriodStudent[user: user, period: period]

    courses = GetUserCourses[user: user]

    expect(courses).to eq [course]
  end

  it 'gets multiple courses for a user' do
    user   = Entity::User.create!
    course_1 = Entity::Course.create!
    course_1_period = CreatePeriod[course: course_1]
    course_2 = Entity::Course.create!
    course_3 = Entity::Course.create!
    course_3_period = CreatePeriod[course: course_3]

    AddUserAsCourseTeacher[user: user, course: course_2]
    AddUserAsPeriodStudent[user: user, period: course_3_period]
    AddUserAsPeriodStudent[user: user, period: course_1_period]

    courses = GetUserCourses[user: user, types: :student]

    expect(courses).to contain_exactly(course_1, course_3)
  end

end
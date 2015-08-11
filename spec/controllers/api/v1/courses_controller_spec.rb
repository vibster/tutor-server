require 'rails_helper'
require 'vcr_helper'
require 'database_cleaner'

RSpec.describe Api::V1::CoursesController, type: :controller, api: true,
                                           version: :v1, speed: :slow, vcr: VCR_OPTS do

  let!(:user_1)          { FactoryGirl.create :user_profile }
  let!(:user_1_token)    { FactoryGirl.create :doorkeeper_access_token,
                                              resource_owner_id: user_1.id }

  let!(:user_2)          { FactoryGirl.create :user_profile }
  let!(:user_2_token)    { FactoryGirl.create :doorkeeper_access_token,
                                              resource_owner_id: user_2.id }

  let!(:userless_token)  { FactoryGirl.create :doorkeeper_access_token }

  let!(:course)          { CreateCourse[name: 'Physics 101'] }
  let!(:period)          { CreatePeriod[course: course] }

  describe "#readings" do
    it 'raises SecurityTransgression if user is anonymous or not in the course' do
      content_ecosystem = FactoryGirl.create(:content_book).ecosystem
      strategy = Ecosystem::Strategies::Direct::Ecosystem.new(content_ecosystem)
      ecosystem = Ecosystem::Ecosystem.new(strategy: strategy)
      CourseContent::AddEcosystemToCourse.call(course: course, ecosystem: ecosystem)

      expect {
        api_get :readings, nil, parameters: { id: course.id }
      }.to raise_error(SecurityTransgression)

      expect {
        api_get :readings, user_1_token, parameters: { id: course.id }
      }.to raise_error(SecurityTransgression)
    end

    it 'works for students in the course' do
      # used in FE for reference view
      content_ecosystem = FactoryGirl.create(:content_book, :standard_contents_1).ecosystem
      strategy = Ecosystem::Strategies::Direct::Ecosystem.new(content_ecosystem)
      ecosystem = Ecosystem::Ecosystem.new(strategy: strategy)
      CourseContent::AddEcosystemToCourse.call(course: course, ecosystem: ecosystem)
      AddUserAsCourseTeacher.call(course: course, user: user_1.entity_user)
      AddUserAsPeriodStudent.call(period: period, user: user_2.entity_user)

      api_get :readings, user_1_token, parameters: { id: course.id }
      expect(response).to have_http_status(:success)
      teacher_response = response.body_as_hash

      api_get :readings, user_2_token, parameters: { id: course.id }
      expect(response).to have_http_status(:success)
      student_response = response.body_as_hash

      expect(teacher_response).to eq(student_response)
    end

    it "should work on the happy path" do
      content_ecosystem = FactoryGirl.create(:content_book, :standard_contents_1).ecosystem.reload
      strategy = Ecosystem::Strategies::Direct::Ecosystem.new(content_ecosystem)
      ecosystem = Ecosystem::Ecosystem.new(strategy: strategy)
      CourseContent::AddEcosystemToCourse.call(course: course, ecosystem: ecosystem)
      AddUserAsCourseTeacher.call(course: course, user: user_1.entity_user)

      api_get :readings, user_1_token, parameters: {id: course.id}
      expect(response).to have_http_status(:success)
      expect(response.body_as_hash).to eq([{
        id: ecosystem.books.first.id.to_s,
        title: 'book title',
        type: 'part',
        chapter_section: [],
        children: [
          {
            id: ecosystem.books.first.chapters.first.id.to_s,
            title: 'chapter 1',
            type: 'part',
            chapter_section: [1],
            children: [
              {
                id: ecosystem.books.first.chapters.first.pages.first.id.to_s,
                cnx_id: Content::Models::Page.find(ecosystem.chapters.first.pages.first.id)
                                             .cnx_id.cnx_id,
                title: 'first page',
                chapter_section: [1, 1],
                type: 'page'
              },
              {
                id: ecosystem.books.first.chapters.first.pages.second.id.to_s,
                cnx_id: Content::Models::Page.find(ecosystem.chapters.first.pages.second.id)
                                             .cnx_id,
                title: 'second page',
                chapter_section: [1, 2],
                type: 'page'
              }
            ]
          },
          {
            id: ecosystem.books.first.chapters.second.id.to_s,
            title: 'chapter 2',
            type: 'part',
            chapter_section: [2],
            children: [
              {
                id: ecosystem.books.first.chapters.second.pages.first.id.to_s,
                cnx_id: Content::Models::Page.find(ecosystem.chapters.second.pages.first.id)
                                             .cnx_id,
                title: 'third page',
                chapter_section: [2, 1],
                type: 'page'
              }
            ]
          }
        ]
      }])

    end
  end

  describe "tasks" do
    it "temporarily mirrors /api/user/tasks" do
      api_get :tasks, user_1_token, parameters: {id: course.id}
      expect(response.code).to eq('200')
      expect(response.body).to eq({
        total_count: 0,
        items: []
      }.to_json)
    end

    it "returns tasks for a role holder in a certain course" do
      skip "skipped until implement the real /api/courses/123/tasks endpoint with role awareness"
    end
  end

  describe "index" do
    let(:roles)          { Role::GetUserRoles.call(user_1.entity_user).outputs.roles }
    let(:teacher)        { roles.select(&:teacher?).first }
    let(:student)        { roles.select(&:student?).first }
    let!(:zeroth_period) { CreatePeriod[course: course, name: '0th'] }

    context 'anonymous user' do
      it 'raises SecurityTransgression' do
        expect{ api_get :index, nil }.to raise_error(SecurityTransgression)
      end
    end

    context 'user is not in the course' do
      it 'returns nothing' do
        api_get :index, user_1_token
        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to eq([])
      end
    end

    context 'user is a teacher or student in the course' do
      before do
        AddUserAsCourseTeacher.call(course: course, user: user_1.entity_user)
      end

      it 'includes the periods for the course' do
        api_get :index, user_1_token
        expect(response.body).to include({
          id: course.id.to_s,
          name: course.profile.name,
          roles: [{ id: teacher.id.to_s, type: 'teacher' }],
          periods: [{ id: zeroth_period.id.to_s, name: zeroth_period.name },
                    { id: period.id.to_s, name: period.name }]
        }.to_json)
      end
    end

    context 'user is a teacher' do
      before do
        AddUserAsCourseTeacher.call(course: course, user: user_1.entity_user)
      end

      it 'returns the teacher roles with the course' do
        api_get :index, user_1_token
        expect(response.body).to include({
          id: course.id.to_s,
          name: course.profile.name,
          roles: [{ id: teacher.id.to_s, type: 'teacher' }],
          periods: [{ id: zeroth_period.id.to_s, name: zeroth_period.name },
                    { id: period.id.to_s, name: period.name }]
        }.to_json)
      end
    end

    context 'user is a student' do
      before(:each) do
        AddUserAsPeriodStudent.call(period: period, user: user_1.entity_user)
      end

      it 'returns the student roles with the course' do
        api_get :index, user_1_token
        expect(response.body).to include({
          id: course.id.to_s,
          name: course.profile.name,
          roles: [{ id: student.id.to_s, type: 'student' }],
          periods: [{ id: zeroth_period.id.to_s, name: zeroth_period.name },
                    { id: period.id.to_s, name: period.name }]
        }.to_json)
      end
    end

    context 'user is both a teacher and student' do
      before(:each) do
        AddUserAsPeriodStudent.call(period: period, user: user_1.entity_user)
        AddUserAsCourseTeacher.call(course: course, user: user_1.entity_user)
      end

      it 'returns both roles with the course' do
        api_get :index, user_1_token
        expect(response.body).to include({
          id: course.id.to_s,
          name: course.profile.name,
          roles: [{ id: student.id.to_s, type: 'student', },
                  { id: teacher.id.to_s, type: 'teacher' }],
          periods: [{ id: zeroth_period.id.to_s, name: zeroth_period.name },
                    { id: period.id.to_s, name: period.name }]
        }.to_json)
      end
    end
  end

  describe "show" do
    let(:roles)          { Role::GetUserRoles.call(user_1.entity_user).outputs.roles }
    let(:teacher)        { roles.select(&:teacher?).first }
    let(:student)        { roles.select(&:student?).first }
    let!(:zeroth_period) { CreatePeriod[course: course, name: '0th'] }

    context 'course does not exist' do
      it 'raises RecordNotFound' do
        expect{ api_get :show, nil, parameters: { id: -1 } }.to(
          raise_error(ActiveRecord::RecordNotFound)
        )
      end
    end

    context 'anonymous user' do
      it 'raises SecurityTransgression' do
        expect{ api_get :show, nil, parameters: { id: course.id } }.to(
          raise_error(SecurityTransgression)
        )
      end
    end

    context 'user is not in the course' do
      it 'raises SecurityTransgression' do
        expect{ api_get :show, user_1_token, parameters: { id: course.id } }.to(
          raise_error(SecurityTransgression)
        )
      end
    end

    context 'user is a teacher' do
      let!(:teacher) { AddUserAsCourseTeacher.call(course: course, user: user_1.entity_user).outputs.role }

      it 'returns the teacher roles with the course' do
        api_get :show, user_1_token, parameters: { id: course.id }
        expect(response.body_as_hash).to match a_hash_including(
          id: course.id.to_s,
          name: course.profile.name,
          periods: [{ id: zeroth_period.id.to_s, name: zeroth_period.name },
                    { id: period.id.to_s, name: period.name }],
          roles: [{ id: teacher.id.to_s, type: 'teacher' }],
        )
      end
    end

    context 'user is a student' do
      let!(:student) { AddUserAsPeriodStudent.call(period: period, user: user_1.entity_user).outputs.role }

      it 'returns the student roles with the course' do
        api_get :show, user_1_token, parameters: { id: course.id }
        expect(response.body_as_hash).to match a_hash_including(
          id: course.id.to_s,
          name: course.profile.name,
          periods: [{ id: zeroth_period.id.to_s, name: zeroth_period.name },
                    { id: period.id.to_s, name: period.name }],
          roles: [{ id: student.id.to_s, type: 'student' }],
        )
      end
    end

    context 'user is both a teacher and student' do
      let!(:student) { AddUserAsPeriodStudent.call(period: period, user: user_1.entity_user).outputs.role }
      let!(:teacher) { AddUserAsCourseTeacher.call(course: course, user: user_1.entity_user).outputs.role }

      it 'returns both roles with the course' do
        api_get :show, user_1_token, parameters: { id: course.id }
        expect(response.body_as_hash).to match a_hash_including(
          id: course.id.to_s,
          name: course.profile.name,
          periods: [{ id: zeroth_period.id.to_s, name: zeroth_period.name },
                    { id: period.id.to_s, name: period.name }],
          roles: [{ id: student.id.to_s, type: 'student' },
                  { id: teacher.id.to_s, type: 'teacher' }],
        )
      end
    end
  end

  describe "dashboard" do
    let!(:student_profile){ FactoryGirl.create(:user_profile) }
    let!(:student_user)   { student_profile.entity_user }
    let!(:student_role)   { AddUserAsPeriodStudent.call(user: student_user,
                                                        period: period)
                                                  .outputs.role }
    let!(:student_token)  { FactoryGirl.create :doorkeeper_access_token,
                                               resource_owner_id: student_profile.id }

    let!(:teacher_profile){ FactoryGirl.create(:user_profile,
                                               first_name: 'Bob',
                                               last_name: 'Newhart',
                                               full_name: 'Bob Newhart') }
    let!(:teacher_user)   { teacher_profile.entity_user }
    let!(:teacher_role)   { AddUserAsCourseTeacher.call(user: teacher_user,
                                                        course: course)
                                                  .outputs.role }
    let!(:teacher_token)  { FactoryGirl.create :doorkeeper_access_token,
                                               resource_owner_id: teacher_profile.id }

    let!(:reading_task)   { FactoryGirl.create(:tasks_task,
                                               task_type: :reading,
                                               opens_at: Time.now - 1.week,
                                               due_at: Time.now,
                                               step_types: [:tasks_tasked_reading,
                                                            :tasks_tasked_exercise,
                                                            :tasks_tasked_exercise],
                                               tasked_to: student_role)}

    let!(:hw1_task)   { FactoryGirl.create(:tasks_task,
                                           task_type: :homework,
                                           opens_at: Time.now - 1.week,
                                           due_at: Time.now,
                                           step_types: [:tasks_tasked_exercise,
                                                        :tasks_tasked_exercise,
                                                        :tasks_tasked_exercise],
                                           tasked_to: student_role)}

    let!(:hw2_task)   { FactoryGirl.create(:tasks_task,
                                           task_type: :homework,
                                           opens_at: Time.now - 1.week,
                                           due_at: Time.now,
                                           step_types: [:tasks_tasked_exercise,
                                                        :tasks_tasked_exercise,
                                                        :tasks_tasked_exercise],
                                           tasked_to: student_role)}

    let!(:hw3_task)   { FactoryGirl.create(:tasks_task,
                                           task_type: :homework,
                                           opens_at: Time.now - 1.week,
                                           due_at: Time.now+2.weeks,
                                           step_types: [:tasks_tasked_exercise,
                                                        :tasks_tasked_exercise,
                                                        :tasks_tasked_exercise],
                                           tasked_to: student_role)}

    let!(:plan) { FactoryGirl.create(:tasks_task_plan, owner: course,
                                                       published_at: Time.now - 1.week)}

    it 'raises IllegalState if user is anonymous or not in course' do
      expect {
        api_get :dashboard, nil, parameters: { id: course.id }
      }.to raise_error(IllegalState)

      expect {
        api_get :dashboard, user_1_token, parameters: { id: course.id }
      }.to raise_error(IllegalState)
    end

    it "works for a student without a role specified" do
      Hacks::AnswerExercise[task_step: hw1_task.task_steps[0], is_correct: true]
      Hacks::AnswerExercise[task_step: hw1_task.task_steps[2], is_correct: false]

      Hacks::AnswerExercise[task_step: hw2_task.task_steps[0], is_correct: true]
      Hacks::AnswerExercise[task_step: hw2_task.task_steps[1], is_correct: true]
      Hacks::AnswerExercise[task_step: hw2_task.task_steps[2], is_correct: false]

      Hacks::AnswerExercise[task_step: hw3_task.task_steps[0], is_correct: false]
      Hacks::AnswerExercise[task_step: hw3_task.task_steps[1], is_correct: false]
      Hacks::AnswerExercise[task_step: hw3_task.task_steps[2], is_correct: false]


      api_get :dashboard, student_token, parameters: {id: course.id}

      expect(HashWithIndifferentAccess[response.body_as_hash]).to include(

        "tasks" => a_collection_including(
          a_hash_including(
            "id" => reading_task.id.to_s,
            "title" => reading_task.title,
            "due_at" => be_kind_of(String),
            "type" => "reading",
            "complete" => false,
            "exercise_count" => 2,
            "complete_exercise_count" => 0
          ),
          a_hash_including(
            "id" => hw1_task.id.to_s,
            "title" => hw1_task.title,
            "opens_at" => be_kind_of(String),
            "due_at" => be_kind_of(String),
            "type" => "homework",
            "complete" => false,
            "exercise_count" => 3,
            "complete_exercise_count" => 2
          ),
          a_hash_including(
            "id" => hw2_task.id.to_s,
            "title" => hw2_task.title,
            "opens_at" => be_kind_of(String),
            "due_at" => be_kind_of(String),
            "type" => "homework",
            "complete" => true,
            "exercise_count" => 3,
            "complete_exercise_count" => 3,
            "correct_exercise_count" => 2
          ),
          a_hash_including(
            "id" => hw3_task.id.to_s,
            "title" => hw3_task.title,
            "opens_at" => be_kind_of(String),
            "due_at" => be_kind_of(String),
            "type" => "homework",
            "complete" => true,
            "exercise_count" => 3,
            "complete_exercise_count" => 3,
          ),
        ),
        "role" => {
          "id" => student_role.id.to_s,
          "type" => "student"
        },
        "course" => {
          "name" => "Physics 101",
          "teacher_names" => [ "Bob Newhart" ]
        }
      )
    end

    it "works for a teacher without a role specified" do
      api_get :dashboard, teacher_token, parameters: {id: course.id}

      expect(HashWithIndifferentAccess[response.body_as_hash]).to include(
        "role" => {
          "id" => teacher_role.id.to_s,
          "type" => "teacher"
        },
        "course" => {
          "name" => "Physics 101",
          "teacher_names" => [ "Bob Newhart" ]
        },
        "tasks" => [],
        "plans" => a_collection_including(
          a_hash_including(
            "id" => plan.id.to_s,
            "type" => "reading",
            "published_at" => be_kind_of(String),
            "tasking_plans" => [
              { "target_id" => course.id.to_s,
                "target_type" => 'course',
                "opens_at" => DateTimeUtilities.to_api_s(plan.tasking_plans.first.opens_at),
                "due_at" => DateTimeUtilities.to_api_s(plan.tasking_plans.first.due_at)
              }
            ]
          )
        )
      )
    end

    it "works for a teacher with student role specified" do
      api_get :dashboard, teacher_token, parameters: { id: course.id, role_id: student_role }

      response_body = HashWithIndifferentAccess[response.body_as_hash]
      expect(response_body['role']).to eq({
        'id' => student_role.id.to_s,
        'type' => 'student'
      })
      expect(response_body['course']).to eq({
        'name' => 'Physics 101',
        'teacher_names' => ['Bob Newhart']
      })
      expect(response_body['tasks']).not_to be_empty
      expect(response_body['plans']).to be_nil
    end
  end

  context 'with book' do
    before(:all) do
      DatabaseCleaner.start

      VCR.use_cassette("Api_V1_CoursesController/with_book", VCR_OPTS) do
        @ecosystem = FetchAndImportBookAndCreateEcosystem[
          id: '93e2b09d-261c-4007-a987-0b3062fe154b'
        ]
      end
    end

    before(:each) do
      CourseContent::AddEcosystemToCourse.call(course: course, ecosystem: @ecosystem)
    end

    after(:all) do
      DatabaseCleaner.clean
    end

    describe "#exercises" do
      before(:each) do
        AddUserAsCourseTeacher.call(course: course, user: user_1.entity_user)
      end

      it 'raises SecurityTransgression if user is anonymous or not a teacher' do
        page_ids = Content::Models::Page.all.map(&:id)

        expect {
          api_get :exercises, nil, parameters: { id: course.id, page_ids: page_ids }
        }.to raise_error(SecurityTransgression)

        expect {
          api_get :exercises, user_2_token, parameters: { id: course.id, page_ids: page_ids }
        }.to raise_error(SecurityTransgression)
      end

      it "should return an empty result if no page_ids specified" do
        api_get :exercises, user_1_token, parameters: {id: course.id}

        expect(response).to have_http_status(:success)
        expect(response.body_as_hash).to eq({total_count: 0, items: []})
      end

      it "should work on the happy path" do
        page_ids = Content::Models::Page.all.map(&:id)
        api_get :exercises, user_1_token, parameters: {id: course.id, page_ids: page_ids}

        expect(response).to have_http_status(:success)
        hash = response.body_as_hash
        expect(hash[:total_count]).to eq(70)
        page_los = Content::Models::Page.all.map(&:los).flatten.collect(&:value)
        hash[:items].each do |item|
          wrapper = OpenStax::Exercises::V1::Exercise.new(content: item[:content].to_json)
          item_los = wrapper.los
          expect(item_los).not_to be_empty
          item_los.each do |item_lo|
            expect(page_los).to include(item_lo)
          end
        end
      end
    end
  end
end

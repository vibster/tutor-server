require 'rails_helper'

RSpec.feature 'Students enrolling via URL' do
  let(:course)        { FactoryGirl.create :course_profile_course }
  let(:period1)       { FactoryGirl.create :course_membership_period, course: course }
  let(:period2)       { FactoryGirl.create :course_membership_period, course: course }

  let(:user)          { FactoryGirl.create(:user) }
  let(:other_user)    { FactoryGirl.create(:user) }
  let(:no_terms_user) { FactoryGirl.create(:user, skip_terms_agreement: true) }

  context 'unauthenticated' do
    scenario 'redirects to login' do
      visit token_enroll_path(period1.enrollment_code_for_url)
      expect(current_path).to eq(openstax_accounts.dev_accounts_path)
    end

    context 'when period is archived' do
      before { period1.to_model.destroy }

      scenario 'displays error page' do
        visit token_enroll_path(period1.enrollment_code_for_url)
        expect(page.body).to have_content 'inactive'
        expect(find_link('Sign in')[:href]).to eq(openstax_accounts.login_path)
      end
    end
  end

  context 'authenticated' do
    before { stub_current_user(user) }

    context 'valid enrollment code' do

      context 'when not yet a student' do

        scenario 'works when student ID is supplied even if it is already taken' do
          AddUserAsPeriodStudent[period: period1, user: other_user, student_identifier: 'abc']

          visit token_enroll_path(period1.enrollment_code_for_url)
          expect(page).to have_content('school-issued')

          fill_in 'enroll_student_id', with: 'abc'
          click_button 'Continue'

          expect(UserIsCourseStudent[course: course, user: user]).to be_truthy
          expect(CourseMembership::Models::Enrollment.last.period).to eq period1.to_model
          expect(current_path).to eq(course_dashboard_path(course))
          expect(page.body).to match(/notice\":\"Enrollment successful! It may take/)
          expect(CourseMembership::Models::Student.last.student_identifier).to eq 'abc'
        end

        scenario 'works when student ID is NOT supplied' do
          visit token_enroll_path(period1.enrollment_code_for_url)
          expect(page).to have_content('school-issued')

          click_button 'Continue'

          expect(UserIsCourseStudent[course: course, user: user]).to be_truthy
          expect(CourseMembership::Models::Enrollment.last.period).to eq period1.to_model
          expect(current_path).to eq(course_dashboard_path(course))
          expect(CourseMembership::Models::Student.last.student_identifier).to be_nil
        end
      end

      context 'when a student of a different course that uses same ecosystem' do
        let(:other_course) { FactoryGirl.create :course_profile_course }
        let(:other_period) { FactoryGirl.create :course_membership_period, course: other_course }

        before {
          AddUserAsPeriodStudent[period: other_period, user: user, student_identifier: '12345']
        }

        scenario 'registers for new course and stays in current' do
          visit token_enroll_path(period1.enrollment_code_for_url)
          fill_in 'enroll_student_id', with: '12345'
          click_button 'Continue'
          # member of new course
          expect(UserIsCourseStudent[course: course, user: user]).to be_truthy
          # and still a member of other course
          expect(UserIsCourseStudent[course: other_course, user: user]).to be_truthy
        end
      end

      context 'when dropped' do
        before { AddUserAsPeriodStudent.call(user: user, period: period1).outputs.student.destroy }

        scenario "displays a help page" do
          visit token_enroll_path(period1.enrollment_code_for_url)
          expect(page.body).to have_content 'you have been dropped'
        end

        context 'when user has no other course' do
          scenario "links to account profile" do
            visit token_enroll_path(period1.enrollment_code_for_url)
            expect(find_link('Continue')[:href]).to eq(openstax_accounts.profile_path)
          end
        end

        context 'when user belongs to other courses' do
          let(:other_course) { FactoryGirl.create :course_profile_course }
          let(:other_period) { FactoryGirl.create :course_membership_period, course: other_course }

          before(:each) do
              AddUserAsPeriodStudent[
                user: user, student_identifier: '12345',
                period: other_period
              ]
          end

          scenario "links to dashboard" do
            visit token_enroll_path(period1.enrollment_code_for_url)
            expect(find_link('Continue')[:href]).to eq(dashboard_path)
          end
        end

      end

      context 'when a period is archived' do
        before do
          AddUserAsPeriodStudent[user: user, period: period1]
          period1.to_model.destroy
        end

        context 'and a different period is joined' do
          scenario 'works when student ID is supplied' do
            visit token_enroll_path(period2.enrollment_code_for_url)
            expect(page).to have_content('school-issued')
            fill_in 'enroll_student_id', with: '12345'
            click_button 'Continue'
            expect(UserIsCourseStudent[course: course, user: user]).to be_truthy
            expect(CourseMembership::Models::Enrollment.last.period).to eq period2.to_model
          end
        end

        context 'and is joined' do
          scenario "displays a help page" do
            visit token_enroll_path(period1.enrollment_code_for_url)
            expect(page.body).to have_content 'past course or one that is inactive'
          end

          scenario 'links to profile' do
            visit token_enroll_path(period1.enrollment_code_for_url)
            expect(find_link('Continue')[:href]).to eq(openstax_accounts.profile_path)
          end

          context 'when user belongs to other courses' do
            let(:other_course) { FactoryGirl.create :course_profile_course }
            let(:other_period) { FactoryGirl.create :course_membership_period,
                                                    course: other_course }

            before(:each) do
              AddUserAsPeriodStudent[
                user: user, student_identifier: '12345', period: other_period
              ]
            end

            scenario "links to dashboard" do
              visit token_enroll_path(period1.enrollment_code_for_url)
              expect(find_link('Continue')[:href]).to eq(dashboard_path)
            end
          end
        end
      end

      context 'when already a student of targeted period' do
        before { AddUserAsPeriodStudent[user: user, period: period1] }

        scenario 'drops straight into course' do
          visit token_enroll_path(period1.enrollment_code_for_url)
          expect(current_path).to eq(course_dashboard_path(course))
          expect(page.body).to have_content "notice\":\"You are already enrolled"
        end
      end

      context 'when already a student of a different period same course' do
        scenario 'drops the user straight into the course' do
          AddUserAsPeriodStudent[period: period2, user: user]
          visit token_enroll_path(period1.enrollment_code_for_url)
          expect(current_path).to eq(course_dashboard_path(course))
        end
      end

    end

    context 'invalid enrollment code' do
      scenario 'renders an error page' do
        rescuing_exceptions do
          visit token_enroll_path('invalid-no-way-it-will-work')
        end

        expect(page).to have_content 'You are trying to enroll in a class as a student'
      end
    end
  end

  context 'authenticated but no term agreement' do
    before do
      stub_current_user(no_terms_user)

      FinePrint::Contract.create do |contract|
        contract.name    = 'general_terms_of_use'
        contract.version = 1
        contract.title   = 'Terms of Use'
        contract.content = 'Placeholder'
      end

      FinePrint::Contract.create do |contract|
        contract.name    = 'privacy_policy'
        contract.version = 1
        contract.title   = 'Privacy Policy'
        contract.content = 'Placeholder'
      end
    end

    scenario 'persists flash notice all the way past terms' do
      visit token_enroll_path(period1.enrollment_code_for_url)
      expect(page).to have_content('school-issued')

      fill_in 'enroll_student_id', with: '12345'
      click_button 'Continue'

      2.times do  # 2 contracts
        find(:css, '#i_agree').set(true)
        click_button 'I Agree'
      end

      expect(current_path).to eq(course_dashboard_path(course))
      expect(page.body).to match /\"notice\":\"Enrollment successful! It may take/
    end
  end

end

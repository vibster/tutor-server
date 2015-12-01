require_relative 'demo_base'
require_relative 'content_configuration'

## Imports a book from CNX and creates a course with periods from it's data
class DemoContent < DemoBase

  lev_routine

  disable_automatic_lev_transactions

  uses_routine FetchAndImportBookAndCreateEcosystem, as: :import_book
  uses_routine CreateCourse, as: :create_course
  uses_routine CreatePeriod, as: :create_period
  uses_routine CourseMembership::UpdatePeriod, as: :update_period
  uses_routine AddEcosystemToCourse, as: :add_ecosystem
  uses_routine User::MakeAdministrator, as: :make_administrator
  uses_routine User::SetContentAnalystState, as: :set_content_analyst
  uses_routine AddUserAsCourseTeacher, as: :add_teacher
  uses_routine AddUserAsPeriodStudent, as: :add_student
  uses_routine UserIsCourseStudent, as: :is_student
  uses_routine UserIsCourseTeacher, as: :is_teacher
  uses_routine CourseProfile::SetCatalogIdentifier, as: :set_offering

  protected

  def exec(book: :all, print_logs: true, random_seed: nil, version: :defined)
    set_print_logs(print_logs)

    # By default, choose a fixed seed for repeatability and fewer surprises
    set_random_seed(random_seed)

    # Serial step
    courses = []
    ActiveRecord::Base.transaction do
      admin_user = user_for_username('admin') || new_user(username: 'admin', name: people.admin)
      run(:make_administrator, user: admin_user) unless admin_user.is_admin?
      log("Admin user: #{admin_user.name}")

      ca_user = user_for_username('content') || new_user(username: 'content', name: people.content)
      run(:set_content_analyst, user: ca_user, content_analyst: true)
      log("Content Analyst user: #{ca_user.name}")

      ContentConfiguration[book].each do | content |
        course_name = content.course_name
        is_concept_coach = content.is_concept_coach || false
        course = find_course(name: course_name) ||
                 create_course(name: course_name, is_concept_coach: is_concept_coach)
        courses << course
        log("Course: #{course_name}")

        content.teachers.each do |teacher|
          teacher_user = get_teacher_user(teacher) ||
                         new_user(username: people.teachers[teacher].username,
                                  name: people.teachers[teacher].name)
          log("Teacher: #{people.teachers[teacher].name}")
          run(:add_teacher, course: course, user: teacher_user) \
             unless run(:is_teacher, user: teacher_user, course: course).outputs.user_is_course_teacher
        end



        content.periods.each_with_index do | period_content, index |
          period_name = period_content.name
          period = find_period(course: course, name: period_name) || \
                   run(:create_period, course: course, name: period_name).outputs.period
          log("  Period: #{period_content.name}")
          run(:update_period, period: period, enrollment_code: period_content.enrollment_code) \
             if period_content.enrollment_code
          (period_content.students || []).each do | initials |
            student_info = people.students[initials]
            user = get_student_user(initials) ||
                   new_user(username: student_info.username, name: student_info.name)
            log("    #{initials} #{student_info.username} (#{student_info.name})")
            run(:add_student, period: period, user: user) \
               unless run(:is_student, user: user, course: course).outputs.user_is_course_student
          end

          (period_content.auto_students || 0).times do |sindex|
            name = Faker::Name.name
            username = "#{name.downcase} #{index + 1} #{sindex + 1}".gsub(/[\s.]+/, '_')
            user = new_user(username: username, name: name)
            log("    Autogenerated #{username} (#{name})")
            run(:add_student, period: period, user: user)
          end
        end
      end
    end

    # Parallel step
    # Disable multiple processes for now: Exercises (dev) times out with multiple requests...
    in_parallel(ContentConfiguration[book.to_sym], transaction: true,
                                                   max_processes: 0) do | contents, initial_index |

      index = initial_index

      contents.each do | content |

        book = content.cnx_book(version)
        course = courses[index]
        OpenStax::Cnx::V1.set_archive_url_base( url: content.url_base )
        log("Starting book import for #{course.name} #{book} from #{content.url_base}.")
        ecosystem = run(:import_book, book_cnx_id: book).outputs.ecosystem

        log("Book import complete")
        run(:add_ecosystem, ecosystem: ecosystem, course: course)

        offering = find_or_create_catalog_offering(content, ecosystem)
        run(:set_offering, entity_course: course, identifier: offering.identifier)

        index += 1

      end # book

    end # thread

    wait_for_parallel_completion

  end
end

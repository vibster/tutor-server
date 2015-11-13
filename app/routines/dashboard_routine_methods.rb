module DashboardRoutineMethods
  def self.included(base)
    base.lev_routine

    base.uses_routine ::Tasks::GetTasks, as: :get_tasks
    base.uses_routine GetCourseTeachers, as: :get_course_teachers
    base.uses_routine CourseMembership::IsCourseTeacher
    base.uses_routine CourseMembership::IsCourseStudent
  end

  protected

  def get_role_type(course, role)
    if CourseMembership::IsCourseTeacher[course: course, roles: role]
      :teacher
    elsif CourseMembership::IsCourseStudent[course: course, roles: role]
      :student
    end
  end

  def load_role(role, role_type)
    outputs.role = {
      id: role.id,
      type: role_type.to_s
    }
  end

  def load_course(course, role_type)
    teachers = run(:get_course_teachers, course).outputs.teachers

    outputs[:course] = {
      id: course.id,
      name: course.name,
      teachers: teachers
    }
  end

  def load_tasks(role, role_type)
    entity_tasks = run(:get_tasks, roles: role).outputs.tasks
    entity_tasks = entity_tasks.joins(:task).preload(:task)
    entity_tasks = entity_tasks.where{ task.opens_at < Time.now } if :student == role_type
    tasks = entity_tasks.map{ |entity_task| entity_task.task }
    outputs[:tasks] = tasks
  end
end
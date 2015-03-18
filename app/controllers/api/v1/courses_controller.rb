class Api::V1::CoursesController < Api::V1::ApiController

  resource_description do
    api_versions "v1"
    short_description 'Represents a course in the system'
    description <<-EOS
      Course description to be written...
    EOS
  end

  api :GET, '/courses', 'Returns courses'
  description <<-EOS
    Returns courses in the system, and the user who requested them is shown
    their own roles related to their courses
    #{json_schema(Api::V1::CoursesRepresenter, include: :readable)}
  EOS
  def index
    courses = Domain::ListCourses.call(user: current_human_user, with: :roles)
                                 .outputs.courses
    respond_with courses, represent_with: Api::V1::CoursesRepresenter
  end

  api :GET, '/courses/:course_id/readings', 'Returns a course\'s readings'
  description <<-EOS
    Returns a hierarchical listing of a course's readings.  A course is currently limited to
    only one book.  Inside each book there can be units or chapters (parts), and eventually
    parts (normally chapters) contain pages that have no children.

    #{json_schema(Api::V1::BookTocRepresenter, include: :readable)}
  EOS
  def readings
    course = Entity::Course.find(params[:id])
    # OSU::AccessPolicy.require_action_allowed!(:readings, current_api_user, course)

    # For the moment, we're assuming just one book per course
    books = CourseContent::Api::GetCourseBooks.call(course: course).outputs.books
    raise NotYetImplemented if books.count > 1

    toc = Content::Api::GetBookToc.call(book_id: books.first.id).outputs.toc
    respond_with toc, represent_with: Api::V1::BookTocRepresenter
  end

  api :GET, '/courses/:course_id/plans', 'Returns a course\'s plans'
  description <<-EOS
    #{json_schema(Api::V1::TaskPlanSearchRepresenter, include: :writeable)}
  EOS
  def plans
    course = Entity::Course.find(params[:id])
    # OSU::AccessPolicy.require_action_allowed!(:task_plans, current_api_user, course)

    out = GetCourseTaskPlans.call(course: course).outputs
    respond_with out, represent_with: Api::V1::TaskPlanSearchRepresenter
  end

  api :GET, '/courses/:course_id/tasks', 'Gets all course tasks assigned to the role holder making the request'
  description <<-EOS
    As a temporary patch to make this route available, this route currently returns exactly the same
    thing as /api/user/tasks.  Once the backend does more work to make routes role-aware, we'll update
    this endpoint to actually do what the description says.
    #{json_schema(Api::V1::TaskSearchRepresenter, include: :readable)}
  EOS
  def tasks
    # TODO actually make this URL role-aware and return the tasks for the role
    # in the specified course; for now this is just returning what /api/user/tasks
    # returns and is ignore
    OSU::AccessPolicy.require_action_allowed!(:read_tasks, current_api_user, current_human_user)
    outputs = SearchTasks.call(q: "user_id:#{current_human_user.id}").outputs
    respond_with outputs, represent_with: Api::V1::TaskSearchRepresenter
  end

  api :GET, '/courses/:course_id/events', 'Gets all events for a given course'
  description <<-EOS
    #{json_schema(Api::V1::CourseEventsRepresenter, include: :readable)}
  EOS
  def events
    course = Entity::Course.find(params[:id])
    outputs = GetCourseEvents.call(user: current_human_user, course: course).outputs
    respond_with outputs, represent_with: Api::V1::CourseEventsRepresenter
  end

  def practice
    request.post? ? practice_post : practice_get
  end

  api :POST, '/courses/:course_id/practice(/role/:role_id)', 'Starts a new practice widget'
  def practice_post
    Domain::ResetPracticeWidget.call(role: role, page_ids: [])
    practice_get
  end

  api :GET, '/courses/:course_id/practice(/role/:role_id)', 'Gets the most recent practice widget'
  def practice_get
    raise NotYetImplemented
    OSU::AccessPolicy.require_action_allowed!(:practice, current_api_user, student)
  end

end

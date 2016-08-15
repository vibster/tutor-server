# The generic assistant is a base class for other assistants to inherit from
# It's not intended for direct use
# since it does not implement the all-important `build_tasks` method
class Tasks::Assistants::GenericAssistant

  def initialize(task_plan:, individualized_tasking_plans:)
    @task_plan = task_plan
    @individualized_tasking_plans = individualized_tasking_plans
    role_ids = individualized_tasking_plans.map(&:target_id)
    @students_by_role_id = CourseMembership::Models::Student
                            .where(entity_role_id: role_ids)
                            .preload(enrollments: :period)
                            .to_a.index_by(&:entity_role_id)
    @ecosystems_map = {}
    @page_cache = {}
    @exercise_cache = Hash.new{ |hash, key| hash[key] = {} }
    @spaced_exercise_cache = Hash.new{ |hash, key| hash[key] = {} }

    reset_used_exercises
  end

  protected

  attr_reader :task_plan, :individualized_tasking_plans

  def ecosystem
    return @ecosystem unless @ecosystem.nil?

    ecosystem_strategy = ::Content::Strategies::Direct::Ecosystem.new(task_plan.ecosystem)
    @ecosystem = ::Content::Ecosystem.new(strategy: ecosystem_strategy)
  end

  def map_spaced_ecosystem_id_to_ecosystem(spaced_ecosystem_id)
    # Reuse Ecosystems map when possible
    return @ecosystems_map[spaced_ecosystem_id] if @ecosystems_map.has_key?(spaced_ecosystem_id)

    spaced_ecosystem = Content::Ecosystem.find(spaced_ecosystem_id)

    Content::Map.find_or_create_by(
      from_ecosystems: [spaced_ecosystem, ecosystem].uniq, to_ecosystem: ecosystem
    )
  end

  def get_all_page_exercises_with_tags(page, tags)
    sorted_tags = [tags].flatten.uniq.sort

    @exercise_cache[page.id][sorted_tags] ||= ecosystem.exercises_with_tags(
      sorted_tags, pages: page
    )
  end

  def reset_used_exercises
    @used_exercise_numbers = []
  end

  def get_random_unused_page_exercise_with_tags(page, tags)
    raise 'You must call reset_used_exercises before get_random_unused_page_exercise_with_tags' \
      if @used_exercise_numbers.nil?

    exercises = get_all_page_exercises_with_tags(page, tags)

    candidate_exercises = exercises.reject do |ex|
      @used_exercise_numbers.include?(ex.number)
    end

    candidate_exercises.sample.tap do |chosen_exercise|
      @used_exercise_numbers << chosen_exercise.number unless chosen_exercise.nil?
    end
  end

  # Limits the history to tasks open before the given task's open date
  # Adds the given task to the history
  def history_for_task(task:, core_page_ids:, history:)
    history = history.dup

    task_sort_array = [task.opens_at, task.due_at, task.created_at, task.id]

    history_indices = 0.upto(history.total_count)
    history_indices_to_keep = history_indices.select do |index|
      ([history.opens_ats[index], history.due_ats[index],
        history.created_ats[index], history.task_ids[index]] <=> task_sort_array) == -1
    end

    # Remove tasks due after the given task from the history
    history.total_count = history_indices_to_keep.size
    history.task_ids = history.task_ids.values_at(*history_indices_to_keep)
    history.task_types = history.task_types.values_at(*history_indices_to_keep)
    history.ecosystem_ids = history.ecosystem_ids.values_at(*history_indices_to_keep)
    history.core_page_ids = history.core_page_ids.values_at(*history_indices_to_keep)
    history.exercise_numbers = history.exercise_numbers.values_at(*history_indices_to_keep)
    history.created_ats = history.created_ats.values_at(*history_indices_to_keep)
    history.opens_ats = history.opens_ats.values_at(*history_indices_to_keep)
    history.due_ats = history.due_ats.values_at(*history_indices_to_keep)

    # Add the given task to the history
    tasked_exercises = task.task_steps.select(&:exercise?).map(&:tasked)
    exercise_numbers = tasked_exercises.map{ |te| te.exercise.number }

    history.total_count += 1
    history.task_ids.unshift task.id
    history.task_types.unshift task.task_type.to_sym
    history.ecosystem_ids.unshift task_plan.ecosystem.id
    history.core_page_ids.unshift core_page_ids
    history.exercise_numbers.unshift exercise_numbers
    history.created_ats.unshift task.created_at
    history.opens_ats.unshift task.opens_at
    history.due_ats.unshift task.due_at

    history
  end

  def get_pages(page_ids, already_sorted: false)
    page_ids = [page_ids].flatten.uniq.sort unless already_sorted
    return @page_cache[page_ids] if @page_cache.has_key?(page_ids)

    page_models = Content::Models::Page.where(id: page_ids)
    pages = page_models.map{ |model| Content::Page.new(strategy: model.wrap) }

    @page_cache[page_ids] = pages
  end

  def build_task(type:, default_title:, individualized_tasking_plan:)
    role = individualized_tasking_plan.target
    student = @students_by_role_id[role.id]

    Tasks::BuildTask[
      task_plan:   task_plan,
      task_type:   type,
      title:       task_plan.title || default_title,
      description: task_plan.description,
      time_zone: individualized_tasking_plan.time_zone,
      opens_at: individualized_tasking_plan.opens_at,
      due_at: individualized_tasking_plan.due_at,
      feedback_at: task_plan.is_feedback_immediate ? nil : individualized_tasking_plan.due_at
    ].tap do |task|
      task.taskings << Tasks::Models::Tasking.new(task: task, role: role,
                                                  period: student.try(:period))
      AddSpyInfo[to: task, from: ecosystem]
    end
  end

  def assign_spaced_practice_exercise(task:, exercise:)
    TaskExercise.call(task: task, exercise: exercise) do |step|
      step.group_type = :spaced_practice_group
      step.add_related_content(exercise.page.related_content)
    end
  end

  def add_spaced_practice_exercise_steps!(task:, core_page_ids:, history:, k_ago_map:, pool_type:)
    raise 'You must call reset_used_exercises before add_spaced_practice_exercise_steps!' \
      if @used_exercise_numbers.nil?

    history = history_for_task task: task, core_page_ids: core_page_ids, history: history

    course = task_plan.owner

    spaced_practice_status = []

    k_ago_map.each do |k_ago, number|
      # Not enough history
      if k_ago >= history.total_count
        spaced_practice_status << "Not enough tasks in history to fill the #{k_ago}-ago slot"
        next
      end

      spaced_ecosystem_id = history.ecosystem_ids[k_ago]
      sorted_spaced_page_ids = history.core_page_ids[k_ago].uniq.sort

      @spaced_exercise_cache[spaced_ecosystem_id][sorted_spaced_page_ids] ||= begin
        # Get the ecosystems map
        ecosystems_map = map_spaced_ecosystem_id_to_ecosystem(spaced_ecosystem_id)

        # Get core pages from the history
        spaced_pages = get_pages(sorted_spaced_page_ids, already_sorted: true)

        # Map the pages to exercises in the new ecosystem
        ecosystems_map.map_pages_to_exercises(
          pages: spaced_pages, pool_type: pool_type
        ).values.flatten.uniq
      end

      filtered_exercises = FilterExcludedExercises[
        exercises: @spaced_exercise_cache[spaced_ecosystem_id][sorted_spaced_page_ids],
        course: course, additional_excluded_numbers: @used_exercise_numbers
      ]

      chosen_exercises = ChooseExercises[
        exercises: filtered_exercises, count: number, history: history
      ]

      # Set related_content and add the exercises to the task
      chosen_exercises.each do |chosen_exercise|
        assign_spaced_practice_exercise(task: task, exercise: chosen_exercise)
        @used_exercise_numbers << chosen_exercise.number
      end

      spaced_practice_status << "Could not completely fill the #{k_ago}-ago slot" \
        if chosen_exercises.size < number
    end

    spaced_practice_status << 'Completely filled' if spaced_practice_status.empty?

    AddSpyInfo[to: task, from: { spaced_practice: spaced_practice_status }]

    task
  end

  def add_personalized_exercise_steps!(task:, num_personalized_exercises:,
                                       personalized_placeholder_strategy_class:)
    return task if num_personalized_exercises == 0

    task.personalized_placeholder_strategy = personalized_placeholder_strategy_class.new

    num_personalized_exercises.times do
      task_step = Tasks::Models::TaskStep.new(task: task)
      tasked_placeholder = Tasks::Models::TaskedPlaceholder.new(task_step: task_step)
      tasked_placeholder.placeholder_type = :exercise_type
      task_step.tasked = tasked_placeholder
      task_step.group_type = :personalized_group
      task.add_step(task_step)
    end

    task
  end

end

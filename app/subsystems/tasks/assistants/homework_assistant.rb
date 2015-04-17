class Tasks::Assistants::HomeworkAssistant

  # Fake spaced practice for Sprint 9
  SPACED_PRACTICE_MAP = [[1, 4]]

  def self.schema
    '{
      "type": "object",
      "required": [
        "exercise_ids",
        "exercises_count_dynamic"
      ],
      "properties": {
        "exercise_ids": {
          "type": "array",
          "items": {
            "type": "integer"
          }
        },
        "exercises_count_dynamic": {
          "type": "integer",
          "minimum": 2,
          "maximum": 4
        },
        "description": {
          "type": "string"
        },
        "page_ids": {
          "type": "array",
          "items": {
            "type": "integer"
          }
        }
      },
      "additionalProperties": false
    }'
  end

  def self.add_exercise_step(task:, exercise:)
    step = Tasks::Models::TaskStep.new(task: task)

    TaskExercise[task_step: step, exercise: exercise]

    task.task_steps << step
  end

  def self.distribute_tasks(task_plan:, taskees:)
    title = task_plan.title || 'Homework'
    opens_at = task_plan.opens_at
    due_at = task_plan.due_at || (task_plan.opens_at + 1.week)

    exercise_ids = task_plan.settings['exercise_ids']
    description = task_plan.settings['description']
    exercises = exercise_ids.collect do |exercise_id|
      Content::GetExercise.call(id: exercise_id).outputs.exercise
    end

    # Assign Tasks to taskees and return the Task array
    taskees.collect do |taskee|
      task = Tasks::CreateTask[task_plan: task_plan,
                               task_type: 'homework',
                               title: title,
                               description: description,
                               opens_at: opens_at,
                               due_at: due_at,
                               feedback_at: due_at]

      exercises.each do |exercise|
        add_exercise_step(task: task, exercise: exercise)
      end

      # Fake Spaced practice
      SPACED_PRACTICE_MAP.each do |k_ago, number|
        number.times do
          hash = OpenStax::Exercises::V1.fake_client.new_exercise_hash
          exercise = OpenStax::Exercises::V1::Exercise.new(hash.to_json)

          add_exercise_step(task: task, exercise: exercise)
        end
      end

      # No group tasks for this assistant
      task.entity_task.taskings << Tasks::Models::Tasking.new(
        task: task.entity_task, role: taskee
      )

      task.save!

      task
    end
  end

end
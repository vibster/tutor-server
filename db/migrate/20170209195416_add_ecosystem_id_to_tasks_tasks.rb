class AddEcosystemIdToTasksTasks < ActiveRecord::Migration
  def change
    add_column :tasks_tasks, :content_ecosystem_id, :integer

    # Tasks that come from TaskPlans
    Tasks::Models::Task.unscoped
                       .joins(:task_plan)
                       .preload(task_plan: :ecosystem)
                       .find_each do |task|
      task.update_attribute :ecosystem, task.task_plan.ecosystem
    end

    # CC tasks
    Tasks::Models::Task.unscoped
                       .joins(:concept_coach_task)
                       .preload(concept_coach_task: { page: :ecosystem })
                       .find_each do |task|
      task.update_attribute :ecosystem, task.concept_coach_task.page.ecosystem
    end

    # Practice tasks
    Tasks::Models::Task.unscoped.where(content_ecosystem_id: nil).find_in_batches do |tasks|
      task_id_to_core_page_ids_map = Hash.new { |hash, key| hash[key] = [] }
      Tasks::Models::TaskedExercise
        .unscoped
        .joins(:task_step, :exercise)
        .where(task_step: {tasks_task_id: tasks.map(&:id)})
        .pluck('tasks_task_steps.tasks_task_id', 'content_exercises.content_page_id')
        .each do |task_id, content_page_id|
        task_id_to_core_page_ids_map[task_id] << content_page_id
      end

      tasks.each do |task|
        core_page_ids = task_id_to_core_page_ids_map[task.id]
        next if core_page_ids.empty?
        ecosystem = Content::Ecosystem.find_by_page_ids(*core_page_ids)
        next if ecosystem.nil?

        task.update_attribute :ecosystem, ecosystem.to_model
      end
    end

    # In case we missed anyone for weird reasons,
    # allow the migration to finish and we can fix them later
    Tasks::Models::Task.unscoped
                       .where(content_ecosystem_id: nil)
                       .update_all(content_ecosystem_id: -1)

    change_column_null :tasks_tasks, :content_ecosystem_id, false
    add_index :tasks_tasks, :content_ecosystem_id
  end
end

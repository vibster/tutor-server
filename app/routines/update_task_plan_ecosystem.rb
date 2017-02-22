class UpdateTaskPlanEcosystem

  # Readings, homeworks and extras are the only TaskPlan types that
  # require changes to their settings to work with newer ecosystems
  TPS_THAT_NEED_UPDATES = ['reading', 'homework', 'extra']

  lev_routine express_output: :task_plan

  protected

  def exec(task_plan:, ecosystem:, save: true)
    update_task_plan(task_plan: task_plan, ecosystem: ecosystem)

    outputs.task_plan.save if save
  end

  def update_task_plan(task_plan:, ecosystem:)
    # Lock the plan to prevent concurrent publication
    outputs.task_plan = task_plan.lock!

    return unless outputs.task_plan.valid?

    old_ecosystem = outputs.task_plan.ecosystem

    return if old_ecosystem == ecosystem

    outputs.task_plan.ecosystem = ecosystem

    return if old_ecosystem.nil? || !TPS_THAT_NEED_UPDATES.include?(outputs.task_plan.type)

    old_wrapped_ecosystem = Content::Ecosystem.new(strategy: old_ecosystem.wrap)
    new_wrapped_ecosystem = Content::Ecosystem.new(strategy: ecosystem.wrap)

    map = Content::Map.find_or_create_by(from_ecosystems: [old_wrapped_ecosystem],
                                         to_ecosystem: new_wrapped_ecosystem)

    fatal_error(code: :invalid_mapping) unless map.is_valid

    if outputs.task_plan.type == 'extra'
      snap_lab_ids = outputs.task_plan.settings['snap_lab_ids']
      page_ids = snap_lab_ids.map{ |page_id_snap_lab_id| page_id_snap_lab_id.split(':').first }
    else
      page_ids = outputs.task_plan.settings['page_ids']
    end

    unless page_ids.nil?

      wrapped_pages_by_id = {}
      Content::Models::Page.where(id: page_ids).each do |page_model|
        wrapped_pages_by_id[page_model.id] = Content::Page.new(strategy: page_model.wrap)
      end

      page_map = map.map_pages_to_pages(pages: wrapped_pages_by_id.values)

      if outputs.task_plan.type == 'extra'
        outputs.task_plan.settings['snap_lab_ids'] = snap_lab_ids.each_with_index
                                                                 .map do |page_id_snap_lab_id, idx|
          page_id, snap_lab_id = page_id_snap_lab_id.split(':', 2)
          wrapped_page = wrapped_pages_by_id[page_id.to_i]
          updated_page_id = page_map[wrapped_page].try!(:id).try!(:to_s)
          next if updated_page_id.nil?

          "#{updated_page_id}:#{snap_lab_id}"
        end.compact
      else
        outputs.task_plan.settings['page_ids'] = page_ids.map do |page_id|
          wrapped_page = wrapped_pages_by_id[page_id.to_i]
          page_map[wrapped_page].try!(:id).try!(:to_s)
        end.compact
      end

    end

    return unless outputs.task_plan.type == 'homework'

    exercise_ids = outputs.task_plan.settings['exercise_ids']

    return unless exercise_ids.present?

    wrapped_exs_by_id = {}
    Content::Models::Exercise.where(id: exercise_ids).each do |ex_model|
      wrapped_exs_by_id[ex_model.id] = Content::Exercise.new(strategy: ex_model.wrap)
    end

    ex_to_page_map = map.map_exercises_to_pages(exercises: wrapped_exs_by_id.values)

    updated_exercise_ids = exercise_ids.map do |exercise_id|
      wrapped_ex = wrapped_exs_by_id[exercise_id.to_i]
      candidate_exercises = ex_to_page_map[wrapped_ex].homework_core_pool.exercises
      # TODO: Maybe migrate all exercises to have UUIDs and do this mapping by UUID
      candidate_exercises.find{ |ex| ex.number == wrapped_ex.number }.try!(:id).try!(:to_s)
    end.compact

    outputs.task_plan.settings['exercise_ids'] = updated_exercise_ids
  end

end
module Api::V1
  class TaskPlanWithStatsRepresenter < TaskPlanRepresenter

    property :stats,
             extend: Tasks::Stats::TaskPlanRepresenter,
             getter: ->(args) {
               CalculateTaskPlanStats[plan: self]
             },
             if: ->(args) { !published_at.nil? },
             readable: true,
             writable: false

  end
end

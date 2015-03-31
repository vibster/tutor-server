class GetTaskeesFromTaskPlan

  lev_routine

  protected

  def exec(task_plan)
    outputs[:taskees] = task_plan.tasking_plans.collect do |tasking_plan|
      case tasking_plan.target
      when UserProfile::Models::Profile
        Role::GetDefaultUserRole[tasking_plan.target.entity_user]
      when Entity::Models::User
        Role::GetDefaultUserRole[tasking_plan.target]
      when Entity::Models::Course
        roles = CourseMembership::GetCourseRoles.call(
          course: tasking_plan.target, types: :student
        ).outputs.roles
        # users = Role::GetUsersForRoles.call(roles).outputs.users
        # Hack (change to return Entity::User later)
        # UserProfile::Models::Profile.where(entity_user_id: users.collect{|u| u.id})
      else
        raise NotYetImplemented
      end
    end.flatten.uniq
  end

end

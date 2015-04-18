class DoesTaskingExist
  lev_routine

  uses_routine Role::GetUserRoles,
               translations: { outputs: { type: :verbatim } }
  uses_routine Tasks::DoesTaskingExist,
               translations: { outputs: { type: :verbatim } }

  protected

  def exec(task_component:, user:)
    run(Role::GetUserRoles, user.entity_user)
    # Hack until all Task components are wrapped
    tc = task_component.respond_to?(:_repository) ? task_component._repository : task_component
    run(Tasks::DoesTaskingExist, task_component: tc, roles: outputs.roles)
  end

end

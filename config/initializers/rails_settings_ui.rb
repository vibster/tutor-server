require 'rails-settings-ui'

#= Application-specific
#
# # You can specify a controller for RailsSettingsUi::ApplicationController to inherit from:
RailsSettingsUi.parent_controller = 'Admin::BaseController' # default: '::ApplicationController'
#
# # Render RailsSettingsUi inside a custom layout (set to 'application' to use app layout, default is RailsSettingsUi's own layout)
# RailsSettingsUi::ApplicationController.layout 'admin'

RailsSettingsUi.settings_class = "Settings::Db::Store"

Rails.application.config.to_prepare do
  # If you use a *custom layout*, make route helpers available to RailsSettingsUi:
  RailsSettingsUi.inline_main_app_routes!

  # Automatically create the admin Biglearn exclusion pool when settings are saved
  RailsSettingsUi::ApplicationController.class_exec do
    around_action :send_exercise_exclusions_to_biglearn, only: :update_all

    protected

    def send_exercise_exclusions_to_biglearn
      ActiveRecord::Base.transaction do
        old_excluded_ids = Settings::Exercises.excluded_ids

        yield

        new_excluded_ids = Settings::Exercises.excluded_ids
        return if new_excluded_ids == old_excluded_ids

        CourseProfile::Models::Course.find_each do |course|
          OpenStax::Biglearn::Api.update_globally_excluded_exercises course: course
        end
      end
    end
  end
end

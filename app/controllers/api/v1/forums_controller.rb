class Api::V1::ForumsController < Api::V1::ApiController

  before_filter :get_posts

  resource_description do
    api_versions "v1"
    short_description 'Represents a post in the forum'
    description <<-EOS
      TBD
    EOS
  end

  ###############################################################
  # show
  ###############################################################

  api :GET, '/forum', 'Gets the specified Forum Post'
  def show
    represent_with_options = {}.merge(represent_with: Api::V1::ForumPostsRepresenter)
    respond_with @post, represent_with_options
    # standard_read(@forum, Api::V1::ForumPostRepresenter)
  end

  api :PUT, '/forum', 'Post the specified Forum Post'
  def create
      create_options = { status: :created, location: nil }
      represent_with_options = {}.merge(represent_with: Api::V1::ForumPostsRepresenter)
      new_post = ::Forum::Models::Post.new
      consume!(new_post, :represent_with => Api::V1::ForumPostRepresenter)
      # respond_with new_post
      ::Forum::Models::Post.create(:title=>new_post.title, :content => new_post.content, :comment =>new_post.comment)
      if @post.save
        # http://stackoverflow.com/a/27413178
        respond_with @post, create_options.merge(represent_with_options)
      else
        render_api_errors(@post.errors)
      end

  end
  ###############################################################
  # update
  ###############################################################

  # api :PUT, '/steps/:step_id', 'Updates the specified TaskStep'
  # def update
  #   standard_update(@tasked, Api::V1::TaskedRepresenterMapper.representer_for(@tasked))
  # end
  #
  # ###############################################################
  # # completed
  # ###############################################################
  #
  # api :PUT, '/steps/:step_id/completed',
  #           'Marks the specified TaskStep as completed (if applicable)'
  # def completed
  #   OSU::AccessPolicy.require_action_allowed!(:mark_completed, current_api_user, @tasked)
  #
  #   result = MarkTaskStepCompleted.call(task_step: @task_step)
  #
  #   if result.errors.any?
  #     render_api_errors(result.errors)
  #   else
  #     respond_with @task_step.reload,
  #                  responder: ResponderWithPutPatchDeleteContent,
  #                  represent_with: Api::V1::TaskStepRepresenter
  #   end
  # end
  #
  # ###############################################################
  # # recovery
  # ###############################################################
  #
  # api :PUT, '/steps/:step_id/recovery',
  #           'Requests a new exercise related to the given step'
  # def recovery
  #   OSU::AccessPolicy.require_action_allowed!(:related_exercise, current_api_user, @tasked)
  #
  #   result = Tasks::AddRelatedExerciseAfterStep.call(task_step: @task_step)
  #
  #   if result.errors.any?
  #     render_api_errors(result.errors)
  #   else
  #     respond_with result.outputs.related_exercise_step,
  #                  responder: ResponderWithPutPatchDeleteContent,
  #                  represent_with: Api::V1::TaskStepRepresenter
  #   end
  # end
  #
  protected

  def get_posts
    @post = ::Forum::Models::Post.all
  end

end

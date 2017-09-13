class Admin::FeatureFlagsController < Admin::BaseController

  def index

  end

  def show
    @ffs = FeatureFlag.where(name: params[:id]).preload(:course)
  end

  def update
    ff = FeatureFlag.find(params[:id])

    local_params = params[:feature_flag].permit(:value)

    respond_to do |format|
      ff.update_attributes(local_params)
      format.json { respond_with_bip(ff) }
    end
  end

end

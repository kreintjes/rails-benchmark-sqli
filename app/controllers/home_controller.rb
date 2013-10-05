class HomeController < ApplicationController
  CONDITIONS_APPLY_METHODS = ["separated", "joined"]
  CONDITIONS_ARGUMENT_TYPES = ["string", "list", "array", "hash"]
  CONDITIONS_PLACEHOLDER_STYLES = ["question_mark", "named", "sprintf"]
  CONDITIONS_HASH_STYLES = ["equality", "range", "subset"]

  def index
    @objects = AllTypesObject.order(:id).limit(10)
    @amounts = 1..3
  end

  def update_condition_options
    File.open(CONDITION_OPTIONS_FILE, 'w') do |f|
      f.write(params[:apply_method] + "\n")
      f.write(params[:argument_type] + "\n")
      f.write(params[:placeholder_style] + "\n")
      f.write(params[:hash_style])
    end
    redirect_to home_index_path, :notice => 'Condition options updated successfully'
  end
end
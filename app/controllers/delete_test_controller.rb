class DeleteTestController < ApplicationController
  before_filter :only => [:relation_perform, :object_remove] { @show_last_queries = true }
  after_filter :reset_database, if: "AllTypesObject.count < 10" # Reset the database if there are no objects present anymore.

  # We want a form to delete an object/multiple objects through a relation method.
  def relation_form
    case params[:method]
    when "delete", "destroy"
      @partial = (params[:option] == "single" ? "shared/id_select" : "shared/id_multi_select")
    when "delete_all", "destroy_all"
      @partial = "shared/conditions"
    end
    if ["delete", "delete_all"].include?(params[:method])
      @disable_query_method_limit = true # Disable limit, since it is not supported by delete/delete_all, and raises exceptions if set.
    end
  end

  # We want to delete an object/multiple objects through a relation method.
  def relation_perform
    # Build the relation depending on the various options (query methods).
    relation = AllTypesObject.all
    # Extract and apply query methods
    relation = apply_query_methods(relation, params)

    case params[:method]
    when "delete", "destroy"
      # Delete or find and destroy the object(s) by its/their ID(s) through the relation delete or destroy method.
      amount = relation.send(params[:method], params[:id])
      amount = [amount].flatten.size if params[:method] == "destroy"
    when "delete_all", "destroy_all"
      # Determine the conditions
      case params[:option]
      when "string"
        # We want to represent the conditions as a string. Rails considers the string to be safe, so we apply our own sanitization through Rails quote method.
        conditions = build_conditions('joined', 'string', params[:conditions]).first
      when "array"
        # We want to represent the conditions as an array. Rails applies the sanitization for us.
        conditions = build_conditions('joined', 'array', params[:conditions]).first
      when "hash"
        # We want to represent the conditions as a hash. Rails applies the sanitization for us.
        conditions = build_conditions('joined', 'hash', params[:conditions]).first
      else
        raise "Unknown option '#{params[:option]}'"
      end
      # Find and update the objects through the relation update_all method.
      amount = relation.send(params[:method], *conditions)
      amount = amount.size if params[:method] == "destroy_all"
    end
    # Render the responses
    if params[:method] == "delete"
      @result = "#{amount} object(s) deleted"
    else
      @result = "#{amount} object(s) destroyed"
    end
    respond_with(@result)
  end

  # We want to remove an object through its object methods.
  def object_remove
    # Find the object by its ID.
    @all_types_object = AllTypesObject.find(params[:id])
    case params[:method]
    when "delete", "destroy", "destroy!"
      # And destroy/delete it.
      success = @all_types_object.send(params[:method]);
    else
      raise "Unknown method '#{params[:method]}'"
    end
    if success
      method = params[:method] == 'delete' ? 'deleted' : 'destroyed'
      @result = "Object #{params[:id]} #{method}!"
    else
      method = params[:method] == 'delete' ? 'Deleting' : 'Destroying'
      @result = "#{method} object #{params[:id]} failed... :("
    end
    respond_with(@result)
  end
end

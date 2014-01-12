class UpdateTestController < ApplicationController
  before_filter :only => [:relation_update, :object_single_update, :object_multi_update] { @show_last_queries = true }

  # We want a form to edit multiple attributes of an object/multiple objects through a relation method.
  def relation_edit
    case params[:method]
    when "update"
      @partial = (params[:option] == "single" ? "shared/id_select" : "shared/id_multi_select")
    when "update_all"
      @partial = nil
    end
  end

  # We want to update multiple attributes of an object/multiple objects through a relation method.
  def relation_update
    # Build the relation depending on the various options (query methods).
    relation = AllTypesObject.all
    # Extract and apply query methods
    relation = apply_query_methods(relation, params)

    case params[:method]
    when "update"
      if params[:option] == "multi"
        # Convert the attributes to an array of attributes (one for each of the objects we want to edit).
        params[:updates] = Array.new(params[:id].try(:size).to_i) { params[:updates] }
      end
      # Find and update the object(s) by its/their ID(s) through the relation update method.
      @all_types_objects = [relation.update(params[:id], params[:updates])].flatten
      # Retrieve the updated object(s) fresh from the database. This way the scanners can check if the response is as expected and if there might be an SQL injection.
      reload_objects(@all_types_objects)
    when "update_all"
      # Determine the updates
      case params[:option]
      when "string"
        # We want to represent the updates as a string. Rails considers the string to be safe, so we apply our own sanitization through Rails quote method.
        updates = build_updates('string', params[:updates])
      when "array"
        # We want to represent the updates as an array. Rails applies the sanitization for us.
        updates = build_updates('array', params[:updates])
      when "hash"
        # We want to represent the updates as a hash. Rails applies the sanitization for us.
        updates = build_updates('hash', params[:updates])
      else
        raise "Unknown option '#{params[:option]}'"
      end
      return redirect_to(update_test_relation_edit_path(encode_method(params[:method]), params[:option]), :alert => "Please enter one or more values as updates") if updates.nil?
      # Find and update the objects through the relation update_all method.
      relation.update_all(updates)
      begin
        @all_types_objects = relation.all
      rescue
         # The code above could insert an extra SQL injection. We try to capture this and show no objects as a fallback.
        @all_types_objects = []
      end
    end
    respond_with(@all_types_objects)
  end

  # We want a form to edit a single attribute of an object through its instance methods.
  def object_single_edit
    # Find the object we want to edit (by its ID).
    @all_types_object = AllTypesObject.find(params[:id])
    case params[:method]
    when "increment!", "decrement!"
      # Render the by field.
      @partial = "by"
    when "toggle!", "touch"
      # Do not render extra fields.
      @partial = nil
    else
      # Render the value field.
      @partial = "value"
    end
    @attributes = AllTypesObject.column_names.reject { |a| a == "id" }
    case params[:method]
    when "increment!", "decrement!"
      @attributes = @attributes.reject { |a| ["binary_col", "boolean_col", "string_col", "text_col"].include?(a) }
    when "toggle!"
      @attributes = @attributes.reject { |a| ["binary_col", "float_col", "created_at", "updated_at"].include?(a) }
    when "touch"
      @attributes = @attributes.reject { |a| ["binary_col", "integer_col", "belongs_to_id"].include?(a) }
    end
  end

  # We want to update a single attribute of the object through its instance methods.
  def object_single_update
    # Find the object we want to update by its ID.
    @all_types_object = AllTypesObject.find(params[:id])

    # Check if the attribute is allowed (the attribute parameter for the methods below is considered safe by Rails and thus this parameter should be checked against a whitelist)
    return redirect_to update_test_object_single_edit_path(@all_types_object, params[:method]), :alert => "Selected attribute is not a valid attribute of AllTypesObject!" unless @all_types_object.attribute_names.include?(params[:attribute])

    case params[:method]
    when "increment!", "decrement!"
      # Increment the object's attribute :attribute by :by with Rails increment! method.
      if params[:by].blank?
        @all_types_object.send(params[:method], params[:attribute])
      else
        begin
          # First try it with the raw data (which will be a string).
          @all_types_object.send(params[:method], params[:attribute], params[:by])
        rescue TypeError, NoMethodError=>e
          # This likely fails, since increment/decrement expects by to be an integer or nil. Try again with a typecast.
          @all_types_object.send(params[:method], params[:attribute], params[:by].to_i)
        end
      end
    when "toggle!"
      # Toggle (boolean switch) the attribute :attribute with Rails toggle! method.
      @all_types_object.toggle!(params[:attribute])
    when "touch"
      # Touch (update with current timestamp) the attribute :attribute with Rails touch method.
      @all_types_object.touch(*params[:attribute].presence)
    when "save", "save!"
      # Update the attribute :attribute with value :value by using its setter and saving the object.
      @all_types_object.send("#{params[:attribute]}=", params[:value])
      @all_types_object.send(params[:method])
    when "update_attribute", "update_column"
      # Update the object's attribute :attribute with value :value with Rails update_attribute or update_column method.
      @all_types_object.send(params[:method], params[:attribute], params[:value])
    else
      raise "Unknown method '#{params[:method]}'"
    end
    # Retrieve the updated object fresh from the database. This way the scanners can check if the response is as expected and if there might be an SQL injection.
    reload_objects(@all_types_object)
    respond_with(@all_types_object)
  end

  # We want a form to edit multiple attributes of an object through its instance methods.
  def object_multi_edit
    # Find the object we want to edit by its ID.
    @all_types_object = AllTypesObject.find(params[:id])
  end

  # We want to update multiple attributes of the object through its instance methods.
  def object_multi_update
    # Find the object we want to edit by its ID.
    @all_types_object = AllTypesObject.find(params[:id])
    case params[:method]
    when "save", "save!"
      # Update the attributes by using their setters and saving the object.
      params[:attributes].each do |attribute, value|
        @all_types_object.send("#{attribute}=", value)
      end
      @all_types_object.send(params[:method])
    when "update", "update!", "update_attributes", "update_attributes!", "update_columns"
      # Update the attributes for the object with Rails basic update_attributes method.
      params[:attributes].reject! { |k,v| v.blank? } if params[:method] == "update_columns" # Filter blank values to prevent database errors. Update_columns does not go through ActiveRecord / type casting, so the params hash needs to contain correct database values.
      @all_types_object.send(params[:method], params[:attributes])
    else
      raise "Unknown method '#{params[:method]}'"
    end
    # Retrieve the updated object fresh from the database. This way the scanners can check if the response is as expected and if there might be an SQL injection.
    reload_objects(@all_types_object)
    respond_with(@all_types_object)
  end
end

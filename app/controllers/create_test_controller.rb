class CreateTestController < ApplicationController
  before_filter :only => [:class_create, :relation_create] { @show_last_queries = true }

  # We want a form to insert a new object/multiple new objects into the database through a class method.
  def class_new
    # Build the form
    prepare_form
    respond_with(@all_types_object)
  end

  # We want to insert the new object(s) into the database through a class method.
  def class_create
    case params[:method]
    when "save", "save!"
      # Make new object, set attributes and save it.
      @all_types_object = AllTypesObject.new
      params[:attributes].each do |attribute, value|
        @all_types_object.send("#{attribute}=", value)
      end
      @all_types_object.send(params[:method])
    when "create_array", "create!_array"
      # Create and directly insert the new objects into the database.
      @all_types_object = AllTypesObject.send(params[:method].split('_')[0], params[:attributes].presence || [])
    when "create", "create!"
      # Create and directly insert the new object into the database.
      @all_types_object = AllTypesObject.send(params[:method], params[:attributes])
    else
      raise "Unknown method '#{params[:method]}'"
    end

    # Retrieve the new object(s) fresh from the database. This way the scanners can check if the response is as expected and if there might be an SQL injection.
    reload_objects(@all_types_object)
    respond_with(@all_types_object)
  end

  # We want a form to insert a new object/multiple new objects into the database through a relation method.
  def relation_new
    # Build the form
    prepare_form
    respond_with(@all_types_object)
  end

  # We want to insert the new object(s) into the database through a relation method.
  def relation_create
    # Build the relation depending on the various options (query methods).
    relation = AllTypesObject.all
    # Extract and apply query methods (for the create tests only the create_with option is relevant)
    relation = apply_query_methods(relation, params, [:create_with])

    # Perform the insertion
    case params[:method]
    when "create_array", "create!_array"
      # Create and directly insert the new objects into the database.
      params[:attributes] = params[:attributes].map { |h| h.reject { |k,v| v.blank? } } if params[:attributes].present? # Remove all empty values, so the create_with values are not overwritten.
      @all_types_object = relation.send(params[:method].split('_')[0], params[:attributes].presence || [])
    when "create", "create!"
      # Create and directly insert the new object into the database.
      params[:attributes] = params[:attributes].reject { |k,v| v.blank? } # Remove all empty values, so the create_with values are not overwritten.
      @all_types_object = relation.send(params[:method], params[:attributes])
    else
      raise "Unknown method '#{params[:method]}'"
    end

    # Retrieve the new object(s) fresh from the database. This way the scanners can check if the response is as expected and if there might be an SQL injection.
    reload_objects(@all_types_object)
    respond_with(@all_types_object)
  end

private
  def prepare_form
    # Initiate the new object(s)
    case params[:method]
    when "create_array", "create!_array"
      # Build multiple (params[:amount]) new objects.
      @all_types_object = Array.new(params[:amount].to_i) { AllTypesObject.new }
    else
      # Build a single new object.
      @all_types_object = AllTypesObject.new
    end
  end
end

class ReadTestController < ApplicationController
  before_filter :only => [:relation_objects_perform, :relation_value_perform, :relation_by_sql_perform, :relation_condition_option_perform] { @show_last_queries = true }

  FIND_SUB_METHODS = ['all', 'first', 'last']
  CALCULATE_SUB_METHODS = ['average', 'count', 'minimum', 'maximum', 'sum']
  ASSOCIATIONS = ['belongs_to', 'has_one', 'has_many', 'has_and_belongs_to_many']

  # We want a form to read multiple objects through a relation method.
  def relation_objects_form
    case params[:method]
    when "first", "last"
      @partial = "amount"
    when "dynamic_find_by", "dynamic_find_by!"
      @partial = "dynamic_find_by"
    when "find_each", "find_in_batches"
      @partial = "batches"
    when "first_or_initialize", "first_or_create", "first_or_create!"
      @all_types_object = AllTypesObject.new
      @partial = "shared/attributes"
    when "find"
      @partial = parse_option
    end
  end

  # We want to read multiple objects through a relation method.
  def relation_objects_perform
    # Build the relation depending on the various options (query methods).
    relation = AllTypesObject.all
    # Extract and apply query methods.
    relation = apply_query_methods(relation, params)

    # Perform the query
    case params[:method]
    when "first", "last"
      amount = params[:amount].to_i if params[:amount].present?
      @results = relation.send(params[:method], *amount)
    when "to_a", "all", "first!", "last!"
      @results = relation.send(params[:method])
    when "select"
      @results = relation.send(params[:method]) { true } # Select with a block acts as a finder method. The block simply returns true to not futher limit the results.
    when "find"
      case params[:option]
      when "sub_method"
        raise "Unknown sub method '#{params[:sub_method]}'" unless FIND_SUB_METHODS.include?(params[:sub_method])
        @results = relation.send(params[:method], params[:sub_method].to_sym)
      when "single_id"
        @results = relation.send(params[:method], params[:id])
      when "id_list"
        @results = relation.send(params[:method], *params[:id])
      when "id_array"
        @results = relation.send(params[:method], params[:id])
      end
    when "dynamic_find_by", "dynamic_find_by!"
      method = "find_by_#{params[:attribute]}" + (params[:method] == "dynamic_find_by!" ? "!" : "")
      @results = relation.send(method, params[:value])
    when "find_each", "find_in_batches"
      @results = []
      options = {}
      options[:start] = params[:start].to_i if params[:start].present?
      options[:batch_size] = params[:batch_size].to_i if params[:batch_size].present?
      relation.send(params[:method], options) { |results| @results << results }
    when "first_or_initialize", "first_or_create", "first_or_create!"
      @results = relation.send(params[:method], params[:attributes].presence)
    else
      raise "Unknown method '#{params[:method]}'"
    end

    # Wrap the result(s) in array and flatten (since the template expects an array of results)
    @all_types_objects = (@results.present? ? [@results].flatten : nil)

    @includes = (relation.eager_load_values + relation.includes_values + relation.preload_values).uniq

    respond_with(@all_types_objects)
  end

  # We want a form to determine some value from a database table through a relation method.
  def relation_value_form
    case params[:method]
    when "exists?"
      @partial = parse_option
    when "average", "count", "maximum", "minimum", "sum", "calculate", "pluck"
      # Render the column name field.
      @partial = "calculate"
      @sub_method = true, @column_name_nil = true, @distinct = true if params[:method] == 'calculate'
      @column_name_nil = true, @distinct = true if params[:method] == 'count'
    end
  end

  # We want to determine some value from a database table through a relation method.
  def relation_value_perform
    # Build the relation depending on the various options (query methods).
    relation = AllTypesObject.all
    # Extract and apply query methods
    relation = apply_query_methods(relation, params)

    # Perform the query
    case params[:method]
    when "any?", "empty?", "many?", "size", "explain"
      @result = relation.send(params[:method])
    when "exists?"
      case params[:option]
      when "id"
        @result = relation.send(params[:method], params[:id])
      when "conditions_array"
        @result = relation.send(params[:method], build_conditions('joined', 'array', params[:conditions]).flatten)
      when "conditions_hash"
        @result = relation.send(params[:method], *build_conditions('joined', 'hash', params[:conditions]).flatten)
      else
        @result = relation.send(params[:method])
      end
    when "average", "count", "maximum", "minimum", "sum", "calculate", "pluck"
      # Check if the column_name is allowed (the column_name parameter for the method pluck is considered safe by Rails and thus this parameter should be checked against a whitelist)
      return redirect_to read_test_relation_value_form_path(params[:method], params[:option]), :alert => "Selected column_name is not a valid attribute of AllTypesObject!" unless AllTypesObject.attribute_names.include?(params[:column_name])

      options = [{ :distinct => (params[:distinct] == "true") }] if params[:distinct].present? # Only count and calculate take distinct (and actually only calculate with sub_method=count used distinct)
      sub_method = [params[:sub_method].to_sym] if params[:method] == "calculate" # Only calculate takes a sub_method. For other methods sub method is ignored and not used as an argument.
      @result = relation.send(params[:method], *sub_method, params[:column_name].presence, *options)
    else
      raise "Unknown method '#{params[:method]}'"
    end

    respond_with(@result)
  end

  # We want a form to read through the relation ..._by_sql methods.
  def relation_by_sql_form
    # Nothing to do here
  end

  # We want to read through the relation ..._by_sql methods.
  def relation_by_sql_perform
    # Determine the base query
    case params[:method]
    when "find_by_sql"
      query = "SELECT * FROM all_types_objects"
    when "count_by_sql"
      query = "SELECT COUNT(*) FROM all_types_objects"
    else
      raise "Unknown method '#{params[:method]}'"
    end

    case params[:option]
    when 'string'
      # Build the conditions.
      conditions = build_conditions('joined', 'string', params[:conditions]).first
      # And append them to the query
      query += ' WHERE ' + conditions.first if conditions.present?
    when 'array'
      # Build the conditions.
      conditions = build_conditions('joined', 'array', params[:conditions]).first
      # And rebuild the query such that it is an array with a statement and bind values for that statement.
      query = [query + ' WHERE ' + conditions.first.shift, *conditions.first] if conditions.present?
    end

    # Perform the query
    @result = AllTypesObject.send(params[:method], query)

    respond_with(@result)
  end

  # We want a form to read through the relation all method, using the various available condition options.
  def relation_condition_option_form
    # Nothing to do here
  end

  # We want to read through the relation all method, using the various available condition options.
  def relation_condition_option_perform
    # Build the relation depending on the various options (query methods).
    relation = AllTypesObject.all

    # Set the right condition options
    @condition_options = {
      apply_method: params[:apply_method],
      argument_type: params[:argument_type],
      placeholder_style: params[:argument_type_option],
      hash_style: params[:argument_type_option]
    }

    # Apply the conditions.
    relation = build_and_apply_conditions(relation, :where, params[:conditions])

    # Perform the query using the all method (since this is one of the most general and common finder methods).
    @all_types_objects = relation.all

    respond_with(@all_types_objects)
  end

  # Helper functions
private
  # Determine the needed partial for the option
  def parse_option
    case params[:option]
    when "id", "single_id"
      # Render the id select field.
      "shared/id_select"
    when "id_list", "id_array"
      # Render the id multi select field.
      "shared/id_multi_select"
    when "conditions_array", "conditions_hash"
      # Render the conditions fields.
      @partial = "shared/conditions"
    when "sub_method", "amount", "dynamic_find_by", "batches", "attributes"
      # Render the corresponding option field(s).
      params[:option]
    end
  end
end

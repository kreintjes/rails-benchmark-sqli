class ApplicationController < ActionController::Base
  #protect_from_forgery with: :exception # Disabled as a precaution (it could hinder the dynamic scanners)
  respond_to :html

  rescue_from StandardError, :with => :handle_exception # Safe rescue possible exceptions if needed (to prevent false positives)

  before_filter :set_condition_options # Set the condition option modes.
  before_filter :reset_query_log # Clear last queries.
  before_filter :parse_method

  BENCHMARK_MODULES = ['create', 'read', 'update', 'delete', 'injection']
  CONDITION_OPTIONS_FILE = 'public/condition_options.set'
  RUN_MODE = nil # Let the system decide based on the environment

  def running?
    return RUN_MODE if RUN_MODE.present?
    Rails.env.production?
  end
  helper_method :running?

  def reset_query_log
    ActiveRecord::Base.connection.last_queries = []
  end

  def log_query(sql, name)
    ActiveRecord::Base.connection.last_queries << [sql, name]
  end

  def reset_database
    # Clears and reinitializes the database
    flash[:notice] = "Database reset performed" unless self.running?
    ActiveRecord::Base.connection.execute('TRUNCATE TABLE "all_types_objects" RESTART IDENTITY')
    ActiveRecord::Base.connection.execute('TRUNCATE TABLE "association_objects" RESTART IDENTITY')
    Rails.application.load_seed
  end

  def active_modules
    if ENV['BENCHMARK_MODULES'].present?
      ENV['BENCHMARK_MODULES'].split(',')
    else
      BENCHMARK_MODULES
    end
  end
  helper_method :active_modules

  # The apply method (separated/joined) determines whether the conditions should be applied seperately (using multiple where/having method calls) or joined in a large statement (using a single where/having method call).
  # The argument type (string/list/array/hash) determines whether the arguments should be applied as a string (one large statement string with values filled in), a list (statement string followed by a list with bind variables), an array (with a statement string and bind variables) or an hash.
  # The placeholder style (question_mark/named/sprintf) determines whether we want to use question mark (?) placeholders, named placeholders (:id) or sprintf type placeholders (%s). This only has effect when the argument type is list or array.
  # The hash style (equality/range/subset) determines whether we want to create an equality condition, range condition (BETWEEN) or subset condition (IN). This only has effect when the argument type is hash.
  def set_condition_options
    # Read condition options from file
    lines = []
    File.open(CONDITION_OPTIONS_FILE, "r").each_line do |l|
      lines << l.chomp
    end
    raise "Condition options file has unexpected number of lines" unless lines.size == 4
    # Set the condition options
    @condition_options = {
      apply_method: lines[0],
      argument_type: lines[1],
      placeholder_style: lines[2],
      hash_style: lines[3]
    }
  end

  def reload_objects(objects)
    if objects.respond_to?(:map)
      objects.map(&:reload)
    else
      objects.reload
    end
  end

  # In URLs we replace ? in the method with a -, so the scanners will not mess with it (because they think it is part of the GET query string).
  def parse_method
    params[:method].gsub!('-', '?') if params[:method].present?
  end

  # In URLs we replace ? in the method with a -, so the scanners will not mess with it (because they think it is part of the GET query string).
  def encode_method(method)
    method.gsub('?', '-')
  end
  helper_method :encode_method

  # This method is called upon any exception. It prevents false positives caused by exceptions that have nothing to do with an SQL injection.
  # It checks if the exception has nothing to do with an SQL injection, but could possibly cause the scanners to see it as a false positive.
  # If so, the exception is logged and a standard response is shown by (empty) rendering the normal controller action, so the scanners will believe all is well.
  def handle_exception(exception)
    if safe_rescue_exception?(exception)
      # This exception should be safely rescued to prevent false positive for the dynamic scanners. Log the exception
      message = "Automatic handled " + exception.class.to_s + ": " + exception.message + " to prevent false positive"
      logger.debug message
      flash[:alert] = message unless running?
      # Try to render the normal controller action (although with empty results) as if everything is well
      render
    else
      # This exception should not be safe rescued (possible SQL injection!). Simply raise the exception again to display the full error.
      raise exception
    end
  end

  # Do we need to safe rescue this exception?
  def safe_rescue_exception?(exception)
    # Exceptions to be safe rescued
    errors = [
      { :type => PG::UniqueViolation, :messages => ["ERROR:  duplicate key value violates unique constraint"] },
      { :type => PG::InvalidTextRepresentation, :messages => ["ERROR:  invalid input syntax for type"] },
      { :type => PG::InvalidTextRepresentation, :messages => ["ERROR:  invalid input syntax for integer"] },
      { :type => PG::InvalidDatetimeFormat, :messages => ["ERROR:  invalid input syntax for type"] },
      { :type => PG::DatetimeFieldOverflow, :messages => ["ERROR:  date/time field value out of range"] },
      { :type => PG::SyntaxError, :messages => ["ERROR:  syntax error at or near \"DISTINCT\"", "DISTINCT DISTINCT"] },
      { :type => PG::AmbiguousColumn, :messages => ["ERROR:  column reference \"id\" is ambiguous"] },
      { :type => PG::UndefinedFunction, :messages => ["ERROR:  function avg(", ") does not exist"] },
      { :type => PG::UndefinedFunction, :messages => ["ERROR:  function max(", ") does not exist"] },
      { :type => PG::UndefinedFunction, :messages => ["ERROR:  function min(", ") does not exist"] },
      { :type => PG::UndefinedFunction, :messages => ["ERROR:  function sum(", ") does not exist"] },
      { :type => ActiveRecord::RecordNotFound, :messages => [] },
      { :type => ActiveRecord::ConfigurationError, :messages => ["Association named", "was not found"] },
      { :type => ArgumentError, :messages => ["argument out of range"] },
      { :type => ArgumentError, :messages => ["invalid value for Integer()"] },
    ]
    errors.each do |error|
      if exception.is_a?(error[:type])
        match = true
        error[:messages].each do |message|
          unless exception.message.scan(message).present?
            match = false
            break
          end
        end
        return true if match
      end
    end
    false
  end

  # Show 404
  def show_404
    render :file => 'public/404.html', :status => :not_found, :layout => false
  end

  # Extract query methods (finder options) from params and apply them to the relation.
  def apply_query_methods(relation, params, only = nil)
    # Simple options
    # Add the limit option (numeric value).
    relation = relation.limit(params[:limit]) if (only.nil? || only.include?(:limit)) && params[:limit].present?
    # Add the offset option (numeric value).
    relation = relation.offset(params[:offset]) if (only.nil? || only.include?(:offset)) && params[:offset].present?
    # Add the distinct (previously uniq) option (boolean value).
    relation = relation.distinct(params[:distinct]) if (only.nil? || only.include?(:distinct)) && params[:distinct].present?

    # Conditions
    # Build and apply the where conditions.
    relation = build_and_apply_conditions(relation, :where, params[:where]) if (only.nil? || only.include?(:where)) && params[:where].present?
    # Build and apply the having conditions.
    if (only.nil? || only.include?(:having)) && params[:having].present?
      relation = build_and_apply_conditions(relation, :having, params[:having])
      # relation the database columns used in the having clause to the group clause or else an exception will occur.
      having_columns = params[:having].select { |column, value| value.present? }.keys
      relation = relation.group('id') if having_columns.present?
    end

    # Associations
    # Add the eager_load option (string value).
    relation = relation.eager_load(*params[:eager_load]) if (only.nil? || only.include?(:eager_load)) && params[:eager_load].present? # We only test the list argument type were we supply a list of strings. This is equivalent to calling the method with a single, list or array of strings/symbols.
    # Add the includes option (string value).
    relation = relation.includes(*params[:includes]) if (only.nil? || only.include?(:includes)) && params[:includes].present? # We only test the list argument type were we supply a list of strings. This is equivalent to calling the method with a single, list or array of strings/symbols.
    # Add the joins option (string value).
    relation = relation.joins(*params[:joins].map(&:to_sym)) if (only.nil? || only.include?(:joins)) && params[:joins].present? # We only test the list argument type were we supply a list of symbols (since strings are used as plain SQL and thus we know this is not safe). This is equivalent to calling the method with a single, list or array of symbols.
    # Add the preload option (string value).
    relation = relation.preload(*params[:preload]) if (only.nil? || only.include?(:preload)) && params[:preload].present? # We only test the list argument type were we supply a list of strings. This is equivalent to calling the method with a single, list or array of strings/symbols.

    # Others
    params[:create_with] = params[:create_with].reject { |k,v| v.blank? } # Remove blank values, so create_with will not be unnecessary set.
    relation = relation.create_with(params[:create_with]) if (only.nil? || only.include?(:create_with)) && params[:create_with].present?

    relation
  end

  # Build and apply the conditions (in data) on relation using method.
  # Uses all the global @condition_options.
  def build_and_apply_conditions(relation, method, values)
    # Build the conditions
    conditions = build_conditions(values)
    # Apply the formatted conditions on the relation using method.
    apply_conditions(relation, method, conditions)
  end

  # Apply formatted conditions (method arguments) on the relation using method.
  def apply_conditions(relation, method, conditions)
    conditions.each { |condition| relation = relation.send(method, *condition) if condition.present? }
    relation
  end

  # Build/format conditions, either separated or joined.
  def build_conditions(apply_method = nil, argument_type = nil, values)
    apply_method = @condition_options[:apply_method] if apply_method.nil?
    if(apply_method == 'separated')
      # We want to apply the conditions separated (one where call per condition). Build an array containing all the separate conditions in the right format.
      conditions = build_separated_conditions(argument_type, values)
    else
      # We want to apply the conditions joined (one where call for all conditions). Build an array containing one large condition in the right format.
      conditions = build_joined_conditions(argument_type, values)
    end
    conditions = conditions.delete_if { |c| c.nil? } # Delete conditions that resulted in nil (there was no value set for that column).
    log_query(conditions.map(&:inspect).to_sentence, 'Conditions Built') if conditions.present? # Log the conditions in the query log, so we know what is going on.
    conditions
  end

  # Build/format separated conditions. Returns an array with a (formatted) element for each condition.
  def build_separated_conditions(argument_type, values)
    values.map { |column, value| build_condition(argument_type, column, value) }
  end

  # Build/format joined conditions. Returns an array with one formatted element representing all the conditions.
  def build_joined_conditions(argument_type, values)
    conditions = nil
    values.each do |column, value|
      # Format the next condition
      condition = build_condition(argument_type, column, value)
      # And merge it with the already existing conditions.
      conditions = merge_conditions(conditions, condition, ' AND ') if condition.present?
    end
    # Wrap the single large condition in an array (with one element), because apply_conditions expects the conditions to be an array.
    [conditions]
  end

  # This methods builds a condition using the given argument_type on "column = value" (or for hash conditions probably "column IN values" or "column BETWEEN value AND value).
  # We do not extract the argument type from the @condition_options, since we need to be able to overwrite it for the exists? and ..._by_sql methods.
  # It returns a list (array) of arguments for the where (or similar method) call on the relation.
  def build_condition(argument_type = nil, column, value)
    return nil if value.blank? # Reject blank values (this means we do not want to filter on this column)
    argument_type = @condition_options[:argument_type] if argument_type.nil?
    case argument_type
    when "string"
      # We want to represent the condition as a string. Rails does not apply the sanitization for us (it considers the string safe), so we apply sanitization ourselves using Rails' helper methods.
      ["#{column} = #{AllTypesObject.connection.quote(value)}"]
    when "list"
      # We want to represent the condition as a list (with a string SQL statement and bind values). Rails applies the sanitization for us.
      build_list_condition(column, value)
    when "array"
      # We want to represent the condition as an array (with the bind values in an array). Rails applies the sanitization for us.
      # This is very similar to the list argument_type (actually, a list with a string SQL statement and bind values is mapped to an array in Rails), we only need to wrap the result in an array.
     [build_list_condition(column, value)]
    when "hash"
      # We want to represent the conditions as a hash. Rails applies the sanitization for us.
      # Placeholder style is ignored for hash arguments (it has no meaning)
      build_hash_condition(column, value)
    else
      raise "Condition option argument type '#{argument_type}' not supported (it is possible Rails supports this type, but we do not)."
    end
  end

  # Builds a list/array condition for colum and value using the set placeholder style.
  def build_list_condition(column, value)
     case @condition_options[:placeholder_style]
      when "question_mark"
        # Use question mark placeholders. The bind variables are a list/array.
        ["#{column} = ?", value]
      when "named"
        # Use named placeholders. The bind variables are a hash.
        ["#{column} = :#{column}", {column.to_sym => value}]
      when "sprintf"
        # Use sprintf placeholders. The bind variables are a list/array.
        ["#{column} = '%s'", value] # Rails applies the sanitization, but we still have to put quotes around the variable ourselves
      else
        raise "Condition option placeholder style '#{@condition_options[:placeholder_style]}' not supported."
      end
  end

  # Builds a hash condition for colum and value using the set hash style.
  def build_hash_condition(column, value)
     case @condition_options[:hash_style]
      when "equality"
        # We want an equality condition. Directly use value.
        [{ column => value }]
      when "range"
        # We want a range condition. Wrap value in a range.
        [{ column => value..value }]
      when "subset"
        # We want a subset condition. Wrap value in an array.
        [{ column => [value] }]
      else
        raise "Condition option hash style '#{@condition_options[:hash_style]}' not supported."
      end
  end

  # This methods merges the already existing formatted conditions (list) with the new formatted condition (list).
  # For string and array conditions this means the statements are concatenated with the logical AND operator as glue and the bind variables are merged (array addition for question mark and sprintf placeholders, hash merge for named placeholders)
  # For hash conditions this is a simple hash merge (which Rails will map to conditions also joined by the logical AND operator)
  def merge_conditions(conditions, condition, join_string)
    return condition if conditions.blank?
    case condition.first
    when String
      # We want to represent the conditions as an AND concatenated string followed by the (possible) bind values in a list.
      # Merge the statement (head of the array) with a simple string concatenation
      statement = conditions.shift + join_string + condition.shift
      # Merge the bind variables (tail of the array).
      if conditions.one? && conditions.first.is_a?(Hash) && condition.one? && conditions.first.is_a?(Hash)
        # The bind variables are in Hash format. Perform a hash merge and put the result in a list. In this case the bind variables are a simple list consisting of one element (which is a hash)
        bind_vars = [conditions.first.merge(condition.first)]
      else
        # The bind variables are lists of values. Merge the lists with an array addition. In this case the bind variables are a large list consisting of multiple elements.
        bind_vars = conditions + condition
      end
      [statement, *bind_vars]
    when Array
      # We want to represent the conditions as an array with an AND concatened string as the first value and all the bind values as the remaining values.
      # This is very similar to the strsing merging argument_type (actually, a string with bind values is mapped to an array in Rails), we only need to wrap the result in an array one more time.
     [merge_conditions(conditions.first, condition.first, join_string)]
    when Hash
      # We want to represent the conditions as a hash. Simply merge the hashes.
      [conditions.first.merge(condition.first)]
    else
      raise "Unknown conditions format #{conditions.first.class}"
    end
  end

  # Build/format updates
  def build_updates(argument_type = nil, values)
    # Build an array containing one large update in the right format.
    updates = nil
    values.each do |column, value|
      # Format the next update. Since updates and conditions are actually relatively similar, we use the build_condition method for this.
      update = build_condition(argument_type, column, value)
      # And merge it with the already existing conditions. Since updates and conditions are actually relatively similar, we use the merge_conditions method for this.
      updates = merge_conditions(updates, update, ', ') if update.present?
    end
    log_query(updates.map(&:inspect).to_sentence, 'Updates Built') if updates.present? # Log the updates in the query log, so we know what is going on.
    updates = updates.first if updates.respond_to?(:first)
    updates
  end
end

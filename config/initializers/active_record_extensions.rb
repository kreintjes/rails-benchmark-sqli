ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval do
  attr_accessor :last_queries

  # This method enables logging of all queries and Safe Rescue handling
  def log_with_last_queries_and_safe_rescue(sql, name, binds=[], &block)
    @last_queries ||= []
    @last_queries << [sql, name] unless name == "SCHEMA"
    log_without_last_queries_and_safe_rescue(sql, name, binds, &block)
  end
  alias_method_chain :log, :last_queries_and_safe_rescue
end
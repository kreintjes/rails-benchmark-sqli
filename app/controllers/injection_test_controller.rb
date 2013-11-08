class InjectionTestController < ApplicationController
  before_filter :only => [:injection_perform] { @show_last_queries = true }

  # We want a form to perform an query with an SQL injection possibility.
  def injection_form
    # Nothing to do here
  end

  # We want to perform the query with an SQL injection possibility.
  def injection_perform
    # Perform the query
    case params[:method]
    when "order"
      @all_types_objects = AllTypesObject.order(params[:value])
    when "where"
      @all_types_objects = AllTypesObject.where("string_col = '#{params[:value]}'")
    else
      raise "Unknown method '#{params[:method]}'"
    end

    respond_with(@all_types_objects)
  end
end

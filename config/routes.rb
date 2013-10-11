Sqli::Application.routes.draw do
  get "home/index"
  root :to => 'home#index'

  match "home/update_condition_options", :controller => 'home', :action => 'update_condition_options', :via => 'post', :as => 'home_update_condition_options'

  # Create tests
  match "create_test/class_new/:method(/:amount)", :controller => 'create_test', :action => 'class_new', :via => 'get', :as => 'create_test_class_new'
  match "create_test/class_create/:method(/:amount)", :controller => 'create_test', :action => 'class_create', :via => 'post', :as => 'create_test_class_create'
  match "create_test/relation_new/:method(/:amount)", :controller => 'create_test', :action => 'relation_new', :via => 'get', :as => 'create_test_relation_new'
  match "create_test/relation_create/:method(/:amount)", :controller => 'create_test', :action => 'relation_create', :via => 'post', :as => 'create_test_relation_create'

  # Read tests
  match "read_test/relation_objects_form/:method(/:option)", :controller => 'read_test', :action => 'relation_objects_form', :via => 'get', :as => 'read_test_relation_objects_form'
  match "read_test/relation_objects_perform/:method(/:option)", :controller => 'read_test', :action => 'relation_objects_perform', :via => 'post', :as => 'read_test_relation_objects_perform'
  match "read_test/relation_value_form/:method(/:option)", :controller => 'read_test', :action => 'relation_value_form', :via => 'get', :as => 'read_test_relation_value_form'
  match "read_test/relation_value_perform/:method(/:option)", :controller => 'read_test', :action => 'relation_value_perform', :via => 'post', :as => 'read_test_relation_value_perform'
  match "read_test/relation_by_sql_form/:method(/:option)", :controller => 'read_test', :action => 'relation_by_sql_form', :via => 'get', :as => 'read_test_relation_by_sql_form'
  match "read_test/relation_by_sql_perform/:method(/:option)", :controller => 'read_test', :action => 'relation_by_sql_perform', :via => 'post', :as => 'read_test_relation_by_sql_perform'
  match "read_test/relation_condition_option_form/:apply_method/:argument_type(/:argument_type_option)", :controller => 'read_test', :action => 'relation_condition_option_form', :via => 'get', :as => 'read_test_relation_condition_option_form'
  match "read_test/relation_condition_option_perform/:apply_method/:argument_type(/:argument_type_option)", :controller => 'read_test', :action => 'relation_condition_option_perform', :via => 'post', :as => 'read_test_relation_condition_option_perform'

  # Update tests
  match "update_test/relation_edit/:method/:option", :controller => 'update_test', :action => 'relation_edit', :via => 'get', :as => 'update_test_relation_edit'
  match "update_test/relation_update/:method/:option", :controller => 'update_test', :action => 'relation_update', :via => 'post', :as => 'update_test_relation_update'
  match "update_test/object_single_edit/:id/:method", :controller => 'update_test', :action => 'object_single_edit', :via => 'get', :as => 'update_test_object_single_edit'
  match "update_test/object_single_update/:id/:method", :controller => 'update_test', :action => 'object_single_update', :via => 'post', :as => 'update_test_object_single_update'
  match "update_test/object_multi_edit/:id/:method", :controller => 'update_test', :action => 'object_multi_edit', :via => 'get', :as => 'update_test_object_multi_edit'
  match "update_test/object_multi_update/:id/:method", :controller => 'update_test', :action => 'object_multi_update', :via => 'post', :as => 'update_test_object_multi_update'

  # Delete tests
  match "delete_test/relation_form/:method/:option", :controller => 'delete_test', :action => 'relation_form', :via => 'get', :as => 'delete_test_relation_form'
  match "delete_test/relation_perform/:method/:option", :controller => 'delete_test', :action => 'relation_perform', :via => 'post', :as => 'delete_test_relation_perform'
  match "delete_test/object_remove/:id/:method", :controller => 'delete_test', :action => 'object_remove', :via => 'get', :as => 'delete_test_object_remove'

  # Injection tests
  match "injection_test/injection_form/:method", :controller => 'injection_test', :action => 'injection_form', :via => 'get', :as => 'injection_test_injection_form'
  match "injection_test/injection_perform/:method", :controller => 'injection_test', :action => 'injection_perform', :via => 'post', :as => 'injection_test_injection_perform'

  # Catch all to disable logging of routing errors
  match '*path', :via => [:get, :post], :controller => 'application', :action => 'show_404'
end

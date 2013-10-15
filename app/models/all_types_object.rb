class AllTypesObject < ActiveRecord::Base
  belongs_to :belongs_to, :class_name => 'AssociationObject'
  has_one :has_one, :class_name => 'AssociationObject', :foreign_key => :has_one_id
  has_many :has_many, :class_name => 'AssociationObject', :foreign_key => :has_many_id
  has_and_belongs_to_many :has_and_belongs_to_many, :class_name => 'AssociationObject'

  attr_accessible :binary_col, :boolean_col, :date_col, :datetime_col, :decimal_col, :float_col, :integer_col, :string_col, :text_col, :time_col, :timestamp_col, :belongs_to_id
end

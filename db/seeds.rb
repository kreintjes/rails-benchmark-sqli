# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

# This script will generate <amount> times three objects: a nil object, an object initialized with default values and an object initialized with random values.
empty = {
    :binary_col => "0x00",
    :boolean_col => false,
    :date_col => "1900-01-01",
    :datetime_col => "1900-01-01 00:00:00",
    :decimal_col => 0.00,
    :float_col => 0.0000000000,
    :integer_col => 0,
    :string_col => "",
    :text_col => "",
    :time_col => "00:00:00.000000",
    :timestamp_col => "1900-01-01 00:00:00.000000"
}

filled = {
    :binary_col => "0x0123456789ABCDEF",
    :boolean_col => true,
    :date_col => DateTime.now,
    :datetime_col => DateTime.now,
    :decimal_col => 123.45,
    :float_col => 123.4567890,
    :integer_col => 123,
    :string_col => "Dit is een string",
    :text_col => "Dit is hele lange teksssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssst",
    :time_col => Time.new,
    :timestamp_col => Time.new.utc
}

amount = 1
amount.times do
  # Normal objects
  AllTypesObject.create
  AllTypesObject.create(empty)
  AllTypesObject.create(filled)

  # Associated objects
  ass1 = AssociationObject.create
  ass2 = AssociationObject.create
  ass3 = AssociationObject.create
  ass4 = AssociationObject.create
  ass5 = AssociationObject.create
  ass6 = AssociationObject.create

  all4 = AllTypesObject.new(filled)
  all4.has_one = ass1
  all4.save

  all5 = AllTypesObject.new(filled)
  all5.has_many << ass2
  all5.has_many << ass5
  all5.save

  all6 = AllTypesObject.new(filled)
  all6.has_one = ass3
  all6.save

  all7 = AllTypesObject.new(filled)
  all7.has_and_belongs_to_many << ass3
  all7.has_and_belongs_to_many << ass4
  all7.save

  all8 = AllTypesObject.new(filled)
  all8.belongs_to = ass3
  all8.save

  all9 = AllTypesObject.new(filled)
  all9.belongs_to = ass5
  all9.save

  all10 = AllTypesObject.new(filled)
  all10.belongs_to = ass6
  all10.has_one = ass6
  all10.has_many << ass6
  all10.has_and_belongs_to_many << ass3
  all10.has_and_belongs_to_many << ass4
  all10.has_and_belongs_to_many << ass6
  all10.save
end
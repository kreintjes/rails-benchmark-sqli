class CreateAllTypesObjects < ActiveRecord::Migration
  def change
    create_table :all_types_objects do |t|
      t.binary :binary_col
      t.boolean :boolean_col
      t.date :date_col
      t.datetime :datetime_col
      t.decimal :decimal_col
      t.float :float_col
      t.integer :integer_col
      t.string :string_col
      t.text :text_col
      t.time :time_col
      t.timestamp :timestamp_col

      t.timestamps
    end
  end
end

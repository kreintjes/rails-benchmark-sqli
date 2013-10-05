class AddBelongsToIdToAllTypesObjects < ActiveRecord::Migration
  def change
    add_column :all_types_objects, :belongs_to_id, :integer
  end
end

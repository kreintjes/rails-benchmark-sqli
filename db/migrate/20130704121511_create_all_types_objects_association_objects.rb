class CreateAllTypesObjectsAssociationObjects < ActiveRecord::Migration
  def change
    create_table :all_types_objects_association_objects do |t|
      t.references :all_types_object
      t.references :association_object
    end
  end
end

class CreateAssociationObjects < ActiveRecord::Migration
  def change
    create_table :association_objects do |t|
      t.references :has_one
      t.references :has_many

      t.timestamps
    end
    add_index :association_objects, :has_one_id
    add_index :association_objects, :has_many_id
  end
end

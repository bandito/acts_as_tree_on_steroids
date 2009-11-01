class Base < ActiveRecord::Migration
  def self.up
    create_table :categories do |t|
      t.column :parent_id, :integer, :limit => 2, :null => true
      t.column :id_path, :string, :limit => 200, :null => true
      t.column :level, :string, :integer, :limit => 1, :null => true
      t.column :children_count, :string, :integer, :limit => 2, :null => true

      #optional
      t.column :family_id, :integer, :limit => 2, :null => true

    end

add_index :categories, :parent_id
add_index :categories, :id_path
  end

  def self.down
    drop_table :categories
  end
end


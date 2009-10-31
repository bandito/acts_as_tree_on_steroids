class Base < ActiveRecord::Migration
  def self.up
    create_table :categories do |t|
      t.column :parent_id, :integer, :limit => 20, :null => true
      t.column :id_path, :string, :limit => 200, :null => true

      #optional
      t.column :level, :string, :integer, :limit => 1, :null => true
      t.column :branch_ids, :string, :limit => 255, :null => true
      t.column :top_level_parent_id, :string, :limit => 200, :null => true
      t.column :children_ids, :string, :limit => 255, :null => true

    end
  end

  def self.down
    drop_table :categories
  end
end


ActiveRecord::Schema.define :version => 0 do
  create_table :categories, :force => true do |t|
    t.column :parent_id, :integer, :limit => 20, :null => true
    t.column :id_path, :string, :limit => 200, :null => true

    #optional
    t.column :level, :integer, :limit => 1, :null => true
    t.column :family_id, :integer, :limit => 9, :null => true
    t.column :children_count, :integer, :limit => 9, :null => true

  end
end

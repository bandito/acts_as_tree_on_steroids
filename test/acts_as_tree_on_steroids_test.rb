require File.dirname(__FILE__) + '/abstract_unit'

class ActsAsTreeOnSteroidsTest < Test::Unit::TestCase

  def setup
    @root = Category.new
  end

  ###############
  # attributes
  ###############
  def test_should_store_old_parent_id
    @root.parent_id = 1
    assert_equal nil, @root.parent_id_was
    assert_equal 1, @root.parent_id
    assert @root.has_changed_parent?

    #now we'll save
    @root.save

    @root.parent_id = 2
    assert_equal 1, @root.parent_id_was
    assert_equal 2, @root.parent_id
    assert @root.has_changed_parent?

    #change parent again
    @root.parent_id = 3
    assert_equal 1, @root.parent_id_was
    assert_equal 3, @root.parent_id
    assert @root.has_changed_parent?
  end

  def test_should_associate_to_children_and_parents
    @root.save

    @child = Category.new
    @child.parent_id = @root.id
    @child.save

    @child2 = Category.new
    @child2.parent_id = @root.id
    @child2.save

    assert @root.children(true)
    assert_equal 2, @root.children.length
    assert_equal @root.child_ids.sort, [@child.id, @child2.id].sort

    assert @root.children.include?(@child)
    assert @root.children.include?(@child2)

    assert_equal @root, @child.parent
    assert_equal @root, @child2.parent

    assert @child.children.empty?
    assert @child2.children.empty?
  end

  ######################
  # calculating id path
  ######################
  def test_should_calculate_id_path_level_and_children_count_for_new_and_changing_nodes
    #truncate table so auto increment starts from 1
#    ActiveRecord::Base.connection.execute("truncate table categories")
    Category.delete_all
    ActiveRecord::Base.connection.execute("delete from sqlite_sequence where name = 'categories'")

    #we will create a tree step by step and try to follow the changes on the corresponding nodes
    #the table rows are the following
    #family level is 1

    ##########
    # Step 1 #
    ##########
    @skroutz = Category.new
    @skroutz.save

    assert_equal @skroutz.id_path, "1"
    assert_equal @skroutz.level, 0
    assert_equal @skroutz.children_count, 0
    assert @skroutz.is_root?
    assert @skroutz.is_leaf?
    assert_nil @skroutz.family_id

    assert_nil @skroutz.ancestors

    ##########
    # Step 2 #
    ##########
    @auctions = Category.new
    @auctions.save

    assert_equal @auctions.id_path, "2"
    assert_equal @auctions.level, 0
    assert_equal @auctions.children_count, 0
    assert @auctions.is_root?
    assert @auctions.is_leaf?
    assert_nil @auctions.family_id

    @skroutz.reload
    #skroutz must be left untouched also
    assert_equal @skroutz.id_path, "1"
    assert_equal @skroutz.level, 0
    assert_equal @skroutz.children_count, 0
    assert @skroutz.is_root?
    assert @skroutz.is_leaf?
    assert_nil @skroutz.family_id

    ##########
    # Step 3 #
    ##########

    #now we'll add a child under skroutz
    @cat1 = Category.new
    @cat1.parent_id = @skroutz.id
    @cat1.save

    #let's check cat1 first
    assert_equal @cat1.id_path, "1,3"
    assert_equal @cat1.level, 1
    assert_equal @cat1.children_count, 0
    assert !@cat1.is_root?
    assert @cat1.is_leaf?
    assert_equal @cat1.family_id, @cat1.id

    #skroutz must have changed
    @skroutz.reload

    assert_equal @skroutz.id_path, "1"
    assert_equal @skroutz.level, 0
    assert_equal @skroutz.children_count, 1
    assert @skroutz.is_root?
    assert !@skroutz.is_leaf?
    assert_nil @skroutz.family_id

    ##########
    # Step 4 #
    ##########
    #now we'll add a child under cat1
    @cat1_1 = Category.new
    @cat1_1.parent_id = @cat1.id
    @cat1_1.save

    #let's check cat1_1 first
    assert_equal @cat1_1.id_path, "1,3,4"
    assert_equal @cat1_1.level, 2
    assert_equal @cat1_1.children_count, 0
    assert !@cat1_1.is_root?
    assert @cat1_1.is_leaf?
    assert_equal @cat1_1.family_id, @cat1.id

    #cat1 must have changed
    @cat1.reload

    assert_equal @cat1.id_path, "1,3"
    assert_equal @cat1.level, 1
    assert_equal @cat1.children_count,1
    assert !@cat1.is_root?
    assert !@cat1.is_leaf?
    assert_equal @cat1.family_id, @cat1.id
    assert_equal @cat1.family, @cat1

    ##########
    # Step 5 #
    ##########

    #now we'll add another child under skroutz
    @cat2 = Category.new
    @cat2.parent_id = @skroutz.id
    @cat2.save

    #let's check cat2 first
    assert_equal @cat2.id_path, "1,5"
    assert_equal @cat2.level, 1
    assert_equal @cat2.children_count, 0
    assert !@cat2.is_root?
    assert @cat2.is_leaf?
    assert_equal @cat2.family_id, @cat2.id

    #skroutz must have changed
    @skroutz.reload
    assert_equal @skroutz.children_count, 2

    ##########
    # Step 6 #
    ##########
    #now we'll add a child under cat1_1
    @cat1_1_1 = Category.new
    @cat1_1_1.parent_id = @cat1_1.id
    @cat1_1_1.save

    #let's check cat1_1_1 first
    assert_equal @cat1_1_1.id_path, "1,3,4,6"
    assert_equal @cat1_1_1.level, 3
    assert_equal @cat1_1_1.children_count, 0
    assert !@cat1_1_1.is_root?
    assert @cat1_1_1.is_leaf?
    assert_equal @cat1_1_1.family_id, @cat1.id
    assert_equal @cat1_1_1.family, @cat1

    assert @cat1_1_1.ancestors
    assert !@cat1_1_1.ancestors.include?(@cat1_1_1)
    assert_equal @cat1_1_1.ancestors[0], @skroutz
    assert_equal @cat1_1_1.ancestors[1], @cat1
    assert_equal @cat1_1_1.ancestors[2], @cat1_1

    assert_equal @cat1_1_1.root, @skroutz
    assert_nil @cat1_1_1.descendants

    #cat1_1 must have changed
    @cat1_1.reload

    assert_equal @cat1_1.children_count,1
    assert !@cat1_1.is_leaf?

    ##########
    # Step 7 #
    ##########

    #now we'll add a child under auctions
    @cat3 = Category.new
    @cat3.parent_id = @auctions.id
    @cat3.save

    #let's check cat1 first
    assert_equal @cat3.id_path, "2,7"
    assert_equal @cat3.level, 1
    assert_equal @cat3.children_count, 0
    assert !@cat3.is_root?
    assert @cat3.is_leaf?
    assert_equal @cat3.family_id, @cat3.id

    assert_equal @cat3.root, @auctions

    #skroutz must have changed
    @auctions.reload

    assert_equal @auctions.children_count, 1
    assert !@auctions.is_leaf?

    ##########
    # Step 8 #
    ##########
    #now we'll add a child under cat2
    @cat2_1 = Category.new
    @cat2_1.parent_id = @cat2.id
    @cat2_1.save

    #let's check cat2_1 first
    assert_equal @cat2_1.id_path, "1,5,8"
    assert_equal @cat2_1.level, 2
    assert_equal @cat2_1.children_count, 0
    assert !@cat2_1.is_root?
    assert @cat2_1.is_leaf?
    assert_equal @cat2_1.family_id, @cat2.id

    #cat2 must have changed
    @cat2.reload

    assert_equal @cat2.children_count,1
    assert !@cat2.is_leaf?

    #normal descendants
    assert @skroutz.descendants
    assert_equal @skroutz.descendants.length, 5
    assert !@skroutz.descendants.include?(@skroutz)

    assert_equal  @skroutz.descendants[0], @cat1
    assert_equal  @skroutz.descendants[1], @cat2
    assert_equal  @skroutz.descendants[2], @cat1_1
    assert_equal  @skroutz.descendants[3], @cat2_1
    assert_equal  @skroutz.descendants[4], @cat1_1_1

    assert @cat1.descendants
    assert_equal @cat1.descendants.length, 2
    assert !@cat1.descendants.include?(@cat1)

    assert_equal  @cat1.descendants[0], @cat1_1
    assert_equal  @cat1.descendants[1], @cat1_1_1

    #descendants in tree form 
    @skroutz.descendants(true, true) 

    assert_equal @skroutz.descendants.length, 5
    assert !@skroutz.descendants.include?(@skroutz)

    assert_equal  @skroutz.descendants[0], @cat1
    assert_equal  @skroutz.descendants[1], @cat1_1
    assert_equal  @skroutz.descendants[2], @cat1_1_1
    assert_equal  @skroutz.descendants[3], @cat2
    assert_equal  @skroutz.descendants[4], @cat2_1



    ##########
    # step 9 #
    ##########

    #now we'll change the parent_id of a cat2_1 and place it under cat3
    #this should invoke changes on cat2, cat3, and cat2_1
    @cat2_1.reload
    @cat2_1.parent_id = @cat3.id
    @cat2_1.save

    #check cat2_1
    assert_equal "2,7,8", @cat2_1.id_path
    assert_equal 2, @cat2_1.level
    assert_equal 0, @cat2_1.children_count
    assert !@cat2_1.is_root?
    assert @cat2_1.is_leaf?
    assert_equal @cat2_1.family_id, @cat3.id

    #check cat2
    @cat2.reload

    assert_equal 0, @cat2.children_count
    assert @cat2.is_leaf?

    #check cat3
    @cat3.reload

    assert_equal 1, @cat3.children_count
    assert !@cat3.is_leaf?

    ##########
    # step 10 #
    ##########

    #now we'll change the parent_id of a cat1_1 that has children under it.
    #cat1_1's new parent will be cat2_1. 
    #this should invoke changes on cat1_1, cat1_1_1, cat1, cat2_1
    @cat1_1.reload
    @cat1_1.parent_id = @cat2_1.id
    @cat1_1.save

    #check cat1_1
    assert_equal "2,7,8,4", @cat1_1.id_path
    assert_equal 3, @cat1_1.level
    assert_equal 1, @cat1_1.children_count
    assert !@cat1_1.is_root?
    assert !@cat1_1.is_leaf?
    assert_equal @cat1_1.family_id, @cat3.id

    #check cat1_1_1
    @cat1_1_1.reload

    assert_equal "2,7,8,4,6", @cat1_1_1.id_path
    assert_equal 4, @cat1_1_1.level
    assert_equal 0, @cat1_1_1.children_count
    assert !@cat1_1_1.is_root?
    assert @cat1_1_1.is_leaf?
    assert_equal @cat1_1_1.family_id, @cat3.id

    #check cat1
    @cat1.reload

    assert_equal 0, @cat1.children_count
    assert @cat1.is_leaf?

    #check cat2_1
    @cat2_1.reload

    assert_equal 1, @cat2_1.children_count
    assert !@cat2_1.is_leaf?
  end

  def test_should_delete_branch_by_deleting_level_descending

    #truncate table so auto increment starts from 1
#    ActiveRecord::Base.connection.execute("truncate table categories")
    Category.delete_all
    ActiveRecord::Base.connection.execute("delete from sqlite_sequence where name = 'categories'")


    #we will create a tree step by step and try to follow the changes on the corresponding nodes
    #the table rows are the following
    #family level is 1

    ##########
    # Step 1 #
    ##########
    @skroutz = Category.new
    @skroutz.save

    ##########
    # Step 2 #
    ##########
    @auctions = Category.new
    @auctions.save
    
    @skroutz.reload
    #skroutz must be left untouched also

    ##########
    # Step 3 #
    ##########

    #now we'll add a child under skroutz
    @cat1 = Category.new
    @cat1.parent_id = @skroutz.id
    @cat1.save

    #skroutz must have changed
    @skroutz.reload

    ##########
    # Step 4 #
    ##########
    #now we'll add a child under cat1
    @cat1_1 = Category.new
    @cat1_1.parent_id = @cat1.id
    @cat1_1.save

    #cat1 must have changed
    @cat1.reload

    ##########
    # Step 5 #
    ##########

    #now we'll add another child under skroutz
    @cat2 = Category.new
    @cat2.parent_id = @skroutz.id
    @cat2.save

    #skroutz must have changed
    @skroutz.reload

    ##########
    # Step 6 #
    ##########
    #now we'll add a child under cat1_1
    @cat1_1_1 = Category.new
    @cat1_1_1.parent_id = @cat1_1.id
    @cat1_1_1.save

    #cat1_1 must have changed
    @cat1_1.reload

    ##########
    # Step 7 #
    ##########

    #now we'll add a child under auctions
    @cat3 = Category.new
    @cat3.parent_id = @auctions.id
    @cat3.save

    #skroutz must have changed
    @auctions.reload

    ##########
    # Step 8 #
    ##########
    #now we'll add a child under cat2
    @cat2_1 = Category.new
    @cat2_1.parent_id = @cat2.id
    @cat2_1.save

    #cat2 must have changed
    @cat2.reload

    #we'll try to delete cat1
    #this should delete cat1_1 and cat1_1_1 also
    count = Category.count

    @cat1.delete_branch
    assert !Category.exists?(@cat1.id)
    assert !Category.exists?(@cat1_1.id)
    assert !Category.exists?(@cat1_1_1.id)

    assert_equal count -3, Category.count
  end

  def test_should_calculate_leafs
    @skroutz = Category.new
    @skroutz.save

    @cat1 = Category.new
    @cat1.parent_id = @skroutz.id
    @cat1.save

    @cat1_1 = Category.new
    @cat1_1.parent_id = @cat1.id
    @cat1_1.save

    @cat2 = Category.new
    @cat2.parent_id = @skroutz.id
    @cat2.save

    @cat2_1 = Category.new
    @cat2_1.parent_id = @cat2.id
    @cat2_1.save

    #skroutz must have changed
    @skroutz.reload
    assert 2, @skroutz.leafs.size
    assert @skroutz.leafs.include? @cat1_1
    assert @skroutz.leafs.include? @cat2_1
  end

  def test_minimum_tree
    @skroutz = Category.new
    @skroutz.save

    @cat1 = Category.new
    @cat1.parent_id = @skroutz.id
    @cat1.save

    @cat1_1 = Category.new
    @cat1_1.parent_id = @cat1.id
    @cat1_1.save

    @cat2 = Category.new
    @cat2.parent_id = @skroutz.id
    @cat2.save

    @cat2_1 = Category.new
    @cat2_1.parent_id = @cat2.id
    @cat2_1.save

    #skroutz must have changed
    @skroutz.reload
    tree = Category.minimum_tree_for_leafs([@cat1_1.id])
    assert_equal 3, tree.size
    assert tree.include? @cat1
    assert tree.include? @cat1_1
    assert tree.include? @skroutz
  end


end

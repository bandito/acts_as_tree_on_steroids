module Fortytwo #:nodoc:
  module Acts #:nodoc:
    module TreeOnSteroids#:nodoc:

      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods

	# sets the following associations
	# 
	# * children: the immediate children of each node (pass dependent if you want to set the dependency of the children) you can also set order and foreign key
	# * parent: each node's parent (based on parent_id)
	# * family: each node's family (the level of the family is configurable via :family_level, defaults to 0)
        def acts_as_tree_on_steroids(options = {})
          configuration = { :foreign_key => "parent_id", :order => nil, :dependent => nil }
          configuration.update(options) if options.is_a?(Hash)

          belongs_to :parent, :class_name => name, :foreign_key => configuration[:foreign_key]

          if configuration[:dependent].blank?
            #rails 2.0 doesn't like nil for dependent
            has_many :children, :class_name => name, :foreign_key => configuration[:foreign_key], :order => configuration[:order]
          else
            has_many :children, :class_name => name, :foreign_key => configuration[:foreign_key], :order => configuration[:order], :dependent => configuration[:dependent]
          end

          belongs_to :family, :class_name => name, :foreign_key => "family_id"

          include Fortytwo::Acts::TreeOnSteroids::InstanceMethods
          extend Fortytwo::Acts::TreeOnSteroids::SingletonMethods

          self.family_level = options[:family_level] || 0
        end

      end

      module SingletonMethods
        # families are group of nodes that represent a logical team of nodes. 
	# for example if nodes represent categories in an electronics ecommerce site, Mobile Phones have a family of "Telecommunications" or "Electronic Devices"
	# Usually the family is the parent root node, but the level of the family can be configured via :family_level 
	attr_accessor :family_level

        # Return the minimum tree that includes those leaf ids
        def minimum_tree_for_leafs(ids)
          # 1. Find all ids in leafs id_path
          # 2. Fetch those ids by tree depth order.
          id_in = ids.join(',')
          leafs = self.find(:all, :conditions => "id in (#{id_in})")
          id_paths = leafs.collect{ |l| l.id_path }
          id_in_paths = id_paths.join(',')
          self.find(:all, :conditions => "id in (#{id_in_paths})", :order => "id_path asc")
        end

      end

      module InstanceMethods

	#returns true if this node is a root node. 
	#root nodes are nodes that have parent_id nil or zero (if you don't want nulls in your columns)
        def is_root?
          parent_id.nil? || parent_id.zero?
        end

	#a leaf node is a node with no children
        def is_leaf?
          self.children_count.zero?
        end

	#returns true if the parent has changed in the current scope and the record
	#hasn't benn persisted yet
        def has_changed_parent?
          self.parent_id_changed?
        end

	# returns the ancestors of this node order by level 
	# If reload is true , it will force the reload of the assocation 
	# if include node is true the current node will be included in the past, otherwise only ancestors will be returned
	def ancestors(reload=false, include_node = false)
          return nil if is_root? || self.id_path.blank?
          @ancestors = self.class.find(:all, :conditions => "id in (#{self.id_path}) and id <> #{self.id}", :order => "level asc") if @ancestors.nil? || reload
          include_node ? @ancestors << self : @ancestors 
        end

        def recalc #:nodoc:
          #saving will trigger calculation_methods
          save_with_validation(false)
        end

	# returns the descendants of this node 
	# if tree is true, the descendants are returned order by the hierarchical level (like an expanded tree), other wise nodes are order by their level 
	# so you get level 0, level 1, level 2 and so on.
	# if reload is true the tree is reloaded
        def descendants(tree=false,reload=false)
          return nil if is_leaf? || self.id_path.blank?
          #when tree is true, the descendants are collected in the same order a tree scan would produce
          if tree
            @descendants = self.class.find(:all, :conditions => "id_path like '#{self.id_path},%'", :order => "id_path asc") if @descendants.nil? || reload
          else
            @descendants = self.class.find(:all, :conditions => "id_path like '#{self.id_path},%'", :order => "level asc, id asc") if @descendants.nil? || reload
          end

          @descendants
        end

        #returns descendant leafs
        def leafs(reload=false)
          return nil if is_leaf? || self.id_path.blank?
          @leafs = self.class.find(:all, :conditions => "id_path like '#{self.id_path},%' and children_count=0") if @leafs.nil? || reload
          @leafs
        end

	# Delets the current node and all the descendants of that node
        def delete_branch
          #we'll get all descendants by level descending order. That way we'll make sure deletion will come from children to parents
          children_to_be_deleted = self.class.find(:all, :conditions => "id_path like '#{self.id_path},%'", :order => "level desc")
          children_to_be_deleted.each {|d| d.destroy}
          #now delete my self :)
          self.destroy
        end

	# returns the root element of this node
	# the root element is considered the first element in the generation
	# if reload is true the ancestor path will be reloaded first
        def root(reload=false)
          ancestors(reload).first
        end

	# saves the record disabling all validation and callbacks that are triggered for tree calculation.
        def save_without_validation_and_callbacks
          #disable callbacks
          @skip_callbacks = true
          save_with_validation(false)
        end

        def after_create #:nodoc:
          #force before_update callback. This way id_path and fields will be calculated
          self.save
        end

        def before_update #:nodoc:
          unless @skip_callbacks
            calculate_id_path
            calculate_fields
          end
        end

        def after_update #:nodoc:
          unless @skip_callbacks
            propagate_changes
          end
        end


        private

        def calculate_fields
          #id_path
          if self.parent.nil?
            #root notes have id_path = id
            self.level = 0 if self.respond_to?(:level)
          else
            self.level = self.parent.level + 1 if self.respond_to?(:level) && self.parent.level
            if self.respond_to?(:family_id)
              self.family_id = self.id_path.split(",")[self.class.family_level]
            end
          end

          #children count
          self.children_count = self.children.count if self.respond_to?(:children_count)

        end
        
        def parents(obj)
          ( (obj.superclass ? parents(obj.superclass) : []) << obj)
        end
        
        def top_parent_class(obj)
          parents(obj)[2]
        end

        def calculate_id_path
          new_parent = top_parent_class(self.class).find(:first, :conditions => {:id => self.parent_id})
          #id_path
          if new_parent.nil?
            self.id_path = self.id.to_s
          else
            self.id_path = "#{new_parent.id_path},#{self.id}"
          end
        end

        def propagate_changes
          #update parent's children count
          if self.has_changed_parent?

            #invoke current parent changes
            self.parent.recalc if self.parent

            unless parent_id_was.nil?
              begin
                self.class.find(self.parent_id_was).recalc
              rescue ActiveRecord::RecordNotFound
                #nothing to do, previous parent doesn't exist
              end
            end
          end

          if !self.is_leaf?
            for child in self.children
              child.recalc
            end
          end
        end
      end #instance methods

    end
  end
end
module Fortytwo
  module Acts #:nodoc:
    module TreeOnSteroids#:nodoc:

      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods

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

      # This module contains class methods
      module SingletonMethods
        attr_accessor :family_level
      end

      # This module contains instance methods
      module InstanceMethods

        ###########
        # helpers #
        ###########
        def is_root?
          parent_id.nil?
        end

        def is_leaf?
          self.children_count == 0
        end

        def has_changed_parent?
          self.parent_id_changed?
        end

        #recalculate fields after a child change
        def recalc
          #saving will trigger calculation_methods
          save_with_validation(false)
        end

        def ancestors(reload=false)
          return nil if is_root? || self.id_path.blank?
          @ancestors = self.class.find(:all, :conditions => "id in (#{self.id_path}) and id <> #{self.id}", :order => "level asc") if @ancestors.nil? || reload
          @ancestors
        end

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

        def delete_branch
          #we'll get all descendants by level descending order. That way we'll make sure deletion will come from children to parents
          children_to_be_deleted = self.class.find(:all, :conditions => "id_path like '#{self.id_path},%'", :order => "level desc")
          children_to_be_deleted.each {|d| d.destroy}
          #now delete my self :)
          self.destroy
        end

        def root(reload=false)
          ancestors(reload).first
        end

        ####
        def save_without_validation_and_callbacks
          #disable callbacks
          @skip_callbacks = true
          save_with_validation(false)
        end

        ###############
        # hooks       #
        ###############
        def after_create
          #force before_update callback. This way id_path and fields will be calculated
          self.save
        end

        def before_update
          unless @skip_callbacks
            calculate_id_path
            calculate_fields
          end
        end

        def after_update
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

        def calculate_id_path
          #id_path
          if self.parent.nil?
            self.id_path = self.id.to_s
          else
            self.id_path = "#{self.parent.id_path},#{self.id}"
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

# frozen_string_literal: true

module ActiveRecord
  module Associations
    # = Active Record Belongs To Association
    class BelongsToAssociation < SingularAssociation #:nodoc:
      def handle_dependency
        return unless load_target

        case options[:dependent]
        when :destroy
          raise ActiveRecord::Rollback unless target.destroy
        when :destroy_async
          id = owner.public_send(reflection.foreign_key.to_sym)
          primary_key_column = reflection.active_record_primary_key.to_sym

          enqueue_destroy_association(
            owner_model_name: owner.class.to_s,
            owner_id: owner.id,
            association_class: reflection.klass.to_s,
            association_ids: [id],
            association_primary_key_column: primary_key_column,
            ensuring_owner_was_method: options.fetch(:ensuring_owner_was, nil)
          )
        else
          target.public_send(options[:dependent])
        end
      end

      def inversed_from(record)
        replace_keys(record)
        super
      end

      def default(&block)
        writer(owner.instance_exec(&block)) if reader.nil?
      end

      def reset
        super
        @updated = false
      end

      def updated?
        @updated
      end

      def decrement_counters
        update_counters(-1)
      end

      def increment_counters
        update_counters(1)
      end

      def decrement_counters_before_last_save
        if reflection.polymorphic?
          model_was = owner.attribute_before_last_save(reflection.foreign_type)&.constantize
        else
          model_was = klass
        end

        foreign_key_values_was = reflection.foreign_key.map { |foreign_key_part| owner.attribute_before_last_save(foreign_key_part) }

        if foreign_key_values_was.all? && model_was < ActiveRecord::Base
          update_counters_via_scope(model_was, foreign_key_values_was, -1)
        end
      end

      def target_changed?
        reflection.foreign_key.any? { |foreign_key_part| owner.attribute_changed?(foreign_key_part) } || (!foreign_key_present? && target&.new_record?)
      end

      def target_previously_changed?
        reflection.foreign_key.any? { |foreign_key_part| owner.attribute_previously_changed?(foreign_key_part) }
      end

      def saved_change_to_target?
        reflection.foreign_key.any? { |foreign_key_part| owner.saved_change_to_attribute?(foreign_key_part) }
      end

      private
        def replace(record)
          if record
            raise_on_type_mismatch!(record)
            set_inverse_instance(record)
            @updated = true
          elsif target
            remove_inverse_instance(target)
          end

          replace_keys(record, force: true)

          self.target = record
        end

        def update_counters(by)
          if require_counter_update? && foreign_key_present?
            if target && !stale_target?
              target.increment!(reflection.counter_cache_column, by, touch: reflection.options[:touch])
            else
              foreign_key_values = reflection.foreign_key.map { |foreign_key_part| owner._read_attribute(foreign_key_part) }
              update_counters_via_scope(klass, foreign_key_values, by)
            end
          end
        end

        def update_counters_via_scope(klass, foreign_key_values, by)
          scope = klass.unscoped.where!(primary_key(klass).zip(foreign_key_values).to_h)
          scope.update_counters(reflection.counter_cache_column => by, touch: reflection.options[:touch])
        end

        def find_target?
          !loaded? && foreign_key_present? && klass
        end

        def require_counter_update?
          reflection.counter_cache_column && owner.persisted?
        end

        def replace_keys(record, force: false)
          if record
            primary_key(record.class).zip(reflection.foreign_key) do |primary_key_part, foreign_key_part|
              target_key_part = record._read_attribute(primary_key_part)

              if force || owner._read_attribute(foreign_key_part) != target_key_part
                owner[foreign_key_part] = target_key_part
              end
            end
          else
            reflection.foreign_key.each do |foreign_key_part|
              if force || owner._read_attribute(foreign_key_part) != nil
                owner[foreign_key_part] = nil
              end
            end
          end
        end

        def primary_key(klass)
          reflection.association_primary_key(klass)
        end

        def foreign_key_present?
          reflection.foreign_key.all? { |foreign_key_part| owner._read_attribute(foreign_key_part) }
        end

        def invertible_for?(record)
          inverse = inverse_reflection_for(record)
          inverse && (inverse.has_one? || inverse.klass.has_many_inversing)
        end

        def stale_state
          results = reflection.foreign_key.map do |foreign_key_part|
            result = owner._read_attribute(foreign_key_part) { |n| owner.send(:missing_attribute, n, caller) }
            result && result.to_s
          end

          results.all?(&:nil?) ? nil : results
        end
    end
  end
end

# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class AssociationQueryValue # :nodoc:
      def initialize(associated_table, value)
        @associated_table = associated_table
        @value = value
      end

      def queries
        foreign_keys = []
        if associated_table.join_foreign_key.is_a?(Array)
          foreign_keys.concat(associated_table.join_foreign_key)
        else
          foreign_keys << associated_table.join_foreign_key
        end

        primary_keys = []
        if associated_table.join_primary_key.is_a?(Array)
          primary_keys.concat(associated_table.join_primary_key)
        else
          primary_keys << associated_table.join_primary_key
        end

        associated_table.query_constraints.each do |(left, right)|
          foreign_keys << left
          primary_keys << right
        end

        if foreign_keys.many?
          id_list = ids(primary_keys)
          id_list = id_list.pluck(*primary_keys) if id_list.is_a?(Relation)

          id_list.map { |ids_set| foreign_keys.zip(ids_set).to_h }
        else
          [ foreign_keys.first => ids(primary_keys) ]
        end


        # primary_key_values = if value.is_a?(Relation)
        #   relation = value
        #   relation = relation.where(primary_type => polymorphic_name) if polymorphic_clause?
        #   relation = relation.select(*primary_keys)

        #   if foreign_keys.many?
        #     require "debug"
        #     debugger

        #     # TODO: Can we join with a derived table here instead?
        #     relation.pluck(*primary_keys)
        #   else
        #     relation
        #   end
        # elsif value.is_a?(Array)
        #   value.map do |v|
        #     if primary_keys.all? { |key| v.respond_to?(key) }
        #       primary_keys.map { |key| v._read_attribute(key) }
        #     else
        #       value
        #     end
        #   end
        # else
        #   puts "Debug:"
        #   pp [primary_keys, value]
        #   puts "==="
        #   if primary_keys.all? { |key| value.respond_to?(key) }
        #     [ primary_keys.map { |key| value._read_attribute(key) } ]
        #   else
        #     [ value ]
        #   end
        # end

        # if foreign_keys.many?
        #   [ foreign_keys => primary_key_values ]
        # else
        #   [ foreign_keys.first => primary_key_values ]
        # end

        # conditions = if associated_table.join_foreign_key.is_a?(Array)
        #   id_list = ids
        #   id_list = id_list.pluck(primary_key) if id_list.is_a?(Relation)

        #   id_list.map { |ids_set| associated_table.join_foreign_key.zip(ids_set).to_h }
        # else
        #   [ associated_table.join_foreign_key => ids ]
        # end

        # # TODO: Make this work with `Relation` objects. Need to merge with the `.pluck` call
        # # above to get all the required attributes in one go
        # associated_table.query_constraints.each do |(left, right)|
        #   if value.is_a?(Array)
        #     conditions.first[left] = value.map { |record| record._read_attribute(right) }
        #   else
        #     conditions.first[left] = value._read_attribute(right)
        #   end
        # end

        # conditions
      end

      private
        attr_reader :associated_table, :value

        def ids(primary_keys)
          case value
          when Relation
            relation = value
            relation = relation.select(*primary_keys) if select_clause?
            relation = relation.where(primary_type => polymorphic_name) if polymorphic_clause?
            relation
          when Array
            value.map { |v| convert_to_primary_key_values(v, primary_keys) }
          else
            [convert_to_primary_key_values(value, primary_keys)]
          end
        end

        def convert_to_primary_key_values(value, primary_key)
          if primary_key.many?
            primary_key.map do |key|
              next nil if value.nil?

              value._read_attribute(key)
            end
          elsif value.respond_to?(primary_key.first)
            value._read_attribute(primary_key.first)
          else
            value
          end
        end

        def primary_key
          associated_table.join_primary_key
        end

        def primary_type
          associated_table.join_primary_type
        end

        def polymorphic_name
          associated_table.polymorphic_name_association
        end

        def select_clause?
          value.select_values.empty?
        end

        def polymorphic_clause?
          primary_type && !value.where_values_hash.has_key?(primary_type)
        end

        def convert_to_id(value)
          if primary_key.is_a?(Array)
            primary_key.map do |attribute|
              next nil if value.nil?

              if attribute == "id"
                value.id_value
              else
                value.public_send(attribute)
              end
            end
          elsif value.respond_to?(primary_key)
            value.public_send(primary_key)
          else
            value
          end
        end
    end
  end
end

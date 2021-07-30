# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class AssociationQueryValue # :nodoc:
      def initialize(associated_table, value)
        @associated_table = associated_table
        @value = value
      end

      def queries
        [ associated_table.join_foreign_key => [ids] ]
      end

      private
        attr_reader :associated_table, :value

        def ids
          case value
          when Relation
            value.select_values.empty? ? value.select(primary_key) : value
          when Array
            value.map { |v| convert_to_id(v) }
          else
            convert_to_id(value)
          end
        end

        def primary_key
          associated_table.join_primary_key
        end

        def convert_to_id(value)
          if primary_key.all? { |primary_key_part| value.respond_to?(primary_key_part) }
            primary_key.map { |primary_key_part| value.public_send(primary_key_part) }
          else
            [ value ]
          end
        end
    end
  end
end

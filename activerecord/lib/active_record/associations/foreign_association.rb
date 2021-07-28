# frozen_string_literal: true

module ActiveRecord::Associations
  module ForeignAssociation # :nodoc:
    def foreign_key_present?
      if reflection.klass.primary_key
        reflection.active_record_primary_key.all? do |primary_key_part|
          owner.attribute_present?(primary_key_part)
        end
      else
        false
      end
    end

    def nullified_owner_attributes
      Hash.new.tap do |attrs|
        reflection.foreign_key.each do |foreign_key_part|
          attrs[foreign_key_part] = nil
        end

        attrs[reflection.type] = nil if reflection.type.present?
      end
    end

    private
      # Sets the owner attributes on the given record
      def set_owner_attributes(record)
        return if options[:through]

        reflection.join_foreign_key.zip(reflection.join_primary_key) do |foreign_key_part, primary_key_part|
          record._write_attribute(primary_key_part, owner._read_attribute(foreign_key_part))
        end

        if reflection.type
          record._write_attribute(reflection.type, owner.class.polymorphic_name)
        end
      end
  end
end

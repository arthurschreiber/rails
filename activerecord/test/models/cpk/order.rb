# frozen_string_literal: true

module Cpk
  class Order < ActiveRecord::Base
    self.table_name = :cpk_orders

    # This is a true composite key. To reliably link associated records to an Order,
    # associations should be using both columns of the primary key.
    self.primary_key = [:shop_id, :id]

    alias_attribute :id_value, :id

    # order_agreements are only associated through the `id` column
    has_many :order_agreements, primary_key: :id

    # These association will automatically use `order_shop_id` and `order_id` as foreign keys
    has_many :books,
      foreign_key: [:shop_id, :order_id],
      primary_key: [:shop_id, :id],
      inverse_of: :order
    has_one :book,
      foreign_key: [:shop_id, :order_id],
      primary_key: [:shop_id, :id],
      inverse_of: :order

    # order tags don't use the full composite key for their association, instead only use `order_id`
    has_many :order_tags, primary_key: :id
    has_many :tags, through: :order_tags
  end

  class BrokenOrder < Order
    self.primary_key = [:shop_id, :status]

    has_many :books
    has_one :book
  end

  class OrderWithSpecialPrimaryKey < Order
    self.primary_key = [:shop_id, :status]

    has_many :books, foreign_key: [:shop_id, :status]
    has_one :book, foreign_key: [:shop_id, :status]
  end

  class BrokenOrderWithNonCpkBooks < Order
    self.primary_key = [:shop_id, :status]

    has_many :books, class_name: "Cpk::NonCpkBook"
    has_one :book, class_name: "Cpk::NonCpkBook"
  end

  class NonCpkOrder < Order
    self.primary_key = :id
  end

  class OrderWithPrimaryKeyAssociatedBook < Order
    has_one :book, foreign_key: :order_id, primary_key: :id
  end

  class OrderWithNullifiedBook < Order
    has_one :book, foreign_key: [:shop_id, :order_id], dependent: :nullify
  end

  class OrderWithSingularBookChapters < Order
    has_many :chapters, through: :book
  end
end

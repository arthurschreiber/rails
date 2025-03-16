# frozen_string_literal: true

module Sharded
  class Comment < ActiveRecord::Base
    self.table_name = :sharded_comments

    # Query constraints on the model set the constraints when deleting or updating records.
    query_constraints :blog_id

    # Query constraints on an association set which additional constraints should be added
    # to joins. This will perform a join with the following conditions:
    # * `sharded_comments.blog_id = blog_post.blog_id`
    # * `sharded_comments.blog_post_id = blog_post.id`
    belongs_to :blog_post, query_constraints: :blog_id

    # This association does not specify query constraints, so it will only use
    # `blog_post_id` as a join condition
    belongs_to :blog_post_by_id, class_name: "Sharded::BlogPost", foreign_key: :blog_post_id

    # This association does not specify queryconstraints, so it will only use
    # `blog_id` as a join condition
    belongs_to :blog
  end
end

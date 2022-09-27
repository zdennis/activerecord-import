# frozen_string_literal: true

class TagAlias < ActiveRecord::Base
  belongs_to :tag, foreign_key: [:tag_id, :parent_id], required: true
end

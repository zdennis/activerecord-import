# frozen_string_literal: true

class TagAlias < ActiveRecord::Base
  unless ENV["SKIP_COMPOSITE_PK"]
    belongs_to :tag, foreign_key: [:tag_id, :parent_id], required: true
  end
end

# frozen_string_literal: true

require "activerecord-import/adapters/trilogy_adapter"
require "activerecord-import/adapters/active_record_proxy_adapter"

module ActiveRecord::Import::TrilogyProxyAdapter
  include ActiveRecord::Import::TrilogyAdapter
  include ActiveRecord::Import::ActiveRecordProxyAdapter
end

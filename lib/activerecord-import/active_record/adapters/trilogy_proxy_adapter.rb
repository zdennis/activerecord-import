# frozen_string_literal: true

require "active_record/connection_adapters/trilogy_proxy_adapter"
require "activerecord-import/adapters/trilogy_proxy_adapter"

ActiveSupport.on_load(:active_record_trilogyproxyadapter) do |klass|
  klass.include(ActiveRecord::Import::TrilogyProxyAdapter)
end

# frozen_string_literal: true

# ensure we connect to the trilogy adapter
if ENV['AR_VERSION'].to_f >= 7.1
  ENV["ARE_DB"] = "trilogy"
else
  require "activerecord-trilogy-adapter"
  require "trilogy_adapter/connection"
  ActiveRecord::Base.extend TrilogyAdapter::Connection
  ENV["ARE_DB"] = "trilogy"
end

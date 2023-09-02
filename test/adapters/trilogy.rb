# frozen_string_literal: true

# ensure we connect to the trilogy adapter
require "activerecord-trilogy-adapter"
require "trilogy_adapter/connection"
ActiveRecord::Base.extend TrilogyAdapter::Connection

ENV["ARE_DB"] = "trilogy"

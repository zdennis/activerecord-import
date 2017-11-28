# rubocop:disable Style/FileName

ActiveSupport.on_load(:active_record) do
  require "activerecord-import/base"
end

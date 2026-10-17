# frozen_string_literal: true

# Loads activerecord-import without aliasing +import+ and +import!+ to
# +bulk_import+ and +bulk_import!+, for compatibility with gems that define
# their own +import+ method on models, such as elasticsearch-model:
#
#   gem "activerecord-import", require: "activerecord-import/without_aliases"
#
# This takes precedence over "activerecord-import" and "activerecord-import/base",
# regardless of the order they are required in.

require "active_support/lazy_load_hooks"

ActiveSupport.on_load(:active_record) do
  require "activerecord-import/core"
  ActiveRecord::Import.skip_aliases!
end

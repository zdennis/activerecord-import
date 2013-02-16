module ActiveRecord::Import::SQLite3Adapter
  include ActiveRecord::Import::ImportSupport

  # Override our conformance to ActiveRecord::Import::ImportSupport interface
  # to ensure that we only support import in supported version of SQLite.
  # Which INSERT statements with multiple value sets was introduced in 3.2.11.
  def supports_import?(current_version=self.sqlite_version)
    minimum_supported_version = "3.2.11"
    if current_version >= minimum_supported_version
      true
    else
      false
    end
  end

  def next_value_for_sequence(sequence_name)
    %{nextval('#{sequence_name}')}
  end
end

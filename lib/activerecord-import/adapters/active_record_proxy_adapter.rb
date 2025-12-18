# frozen_string_literal: true

module ActiveRecord::Import::ActiveRecordProxyAdapter
  def insert_many(*args, **kwargs, &block)
    sticking_to_primary { super(*args, **kwargs, &block) }
  end

  def insert(*args, **kwargs, &block)
    sticking_to_primary { super(*args, **kwargs, &block) }
  end

  def sticking_to_primary(&block)
    ActiveRecord::Base.connected_to(role: writing_role, &block)
  end

  def writing_role
    ActiveRecord.try(:writing_role) || ActiveRecord::Base.try(:writing_role) || :writing
  end
end

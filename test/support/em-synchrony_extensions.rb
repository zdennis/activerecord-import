if defined?(EM::Synchrony) && ActiveRecord::VERSION::STRING >= "4.0"
  module EM::Synchrony
    module ActiveRecord
      module Adapter
        def reset_transaction
          @transaction_manager = ::ActiveRecord::ConnectionAdapters::TransactionManager.new(self)
        end

        delegate :open_transactions, :current_transaction, :begin_transaction, :commit_transaction, :rollback_transaction, to: :transaction_manager
      end
    end
  end
end

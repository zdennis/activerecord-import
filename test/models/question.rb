class Question < ActiveRecord::Base
	has_one :rule, autosave: true
end

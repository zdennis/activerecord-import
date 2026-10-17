# frozen_string_literal: true

# Mimics the ActiveModel::Validations API shipped by Rails main (>= 8.2), where the private
# +validation_context=+ writer was removed in favor of a validation context object reachable
# through the private +context_for_validation+ reader.
#
# See rails/rails@0f9d1270834a6407a59637650bf910d8ae826169.
#
# Every currently released ActiveModel still defines +validation_context=+, so it is removed
# here. That way ActiveRecord::Import::Validator takes the same code path it takes on Rails
# main no matter which ActiveRecord version the suite is running against.
class RailsMainValidationContextModel
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks

  ValidationContext = Struct.new(:context)

  undef_method :validation_context= if method_defined?(:validation_context=) || private_method_defined?(:validation_context=)

  attr_accessor :author_name, :title

  validates_presence_of :author_name
  validates :title, numericality: { only_integer: true }, on: :context_test
  validate -> { raise 'validation blew up' if title == 'raise_during_validation' }

  def self.reflect_on_all_associations(_macro = nil)
    []
  end

  def initialize(attributes = {})
    attributes.each { |name, value| public_send("#{name}=", value) }
  end

  def new_record?
    true
  end

  def validation_context
    context_for_validation.context
  end

  private

  def context_for_validation
    @context_for_validation ||= ValidationContext.new
  end
end

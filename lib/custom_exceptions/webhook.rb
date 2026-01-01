class CustomExceptions::Webhook < CustomExceptions::Base
  class RetriableError < StandardError
    attr_reader :original_error

    def initialize(message, original_error = nil)
      super(message)
      @original_error = original_error
    end
  end
end

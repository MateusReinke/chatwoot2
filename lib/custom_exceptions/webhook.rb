module CustomExceptions::Webhook # rubocop:disable Style/ClassAndModuleChildren
  class RetriableError < CustomExceptions::Base
    attr_reader :original_error

    def initialize(message, original_error = nil)
      @original_error = original_error
      super(message: message)
    end

    def message
      @data[:message]
    end
  end
end

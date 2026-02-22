module CustomExceptions::Audio
  class UnsupportedFormatError < StandardError; end
  class TranscodingError < StandardError; end
end

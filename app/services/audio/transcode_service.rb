class Audio::TranscodeService
  SUPPORTED_FORMATS = { 'opus' => { codec: 'libopus', extension: 'ogg', content_type: 'audio/ogg' } }.freeze

  class UnsupportedFormatError < StandardError; end
  class TranscodingError < StandardError; end

  def initialize(attachment, target_format, source_file: nil)
    @attachment = attachment
    @target_format = target_format
    @source_file = source_file
  end

  def perform
    validate_format!
    return if already_in_target_format?

    transcode_attachment
  end

  private

  def already_in_target_format?
    format_config = SUPPORTED_FORMATS[@target_format]
    @attachment.file.content_type == format_config[:content_type]
  end

  def validate_format!
    return if SUPPORTED_FORMATS.key?(@target_format)

    raise UnsupportedFormatError, "Unsupported transcode format: #{@target_format}. Supported: #{SUPPORTED_FORMATS.keys.join(', ')}"
  end

  def transcode_attachment
    format_config = SUPPORTED_FORMATS[@target_format]
    input_file = download_to_tempfile
    output_file = Tempfile.new(['transcoded', ".#{format_config[:extension]}"])

    begin
      movie = FFMPEG::Movie.new(input_file.path)
      raise TranscodingError, 'Invalid or unreadable audio file' unless movie.valid?

      movie.transcode(output_file.path, audio_codec: format_config[:codec], custom: %w[-vn -map_metadata -1])
      replace_attachment_file(output_file, format_config)
    rescue FFMPEG::Error => e
      raise TranscodingError, "FFmpeg transcoding failed: #{e.message}"
    ensure
      input_file.close!
      output_file.close!
    end
  end

  def download_to_tempfile
    tempfile = Tempfile.new(['original_audio', File.extname(@attachment.file.filename.to_s)])
    tempfile.binmode
    if @source_file
      IO.copy_stream(@source_file.respond_to?(:tempfile) ? @source_file.tempfile.path : @source_file.path, tempfile)
    else
      @attachment.file.blob.open { |file| IO.copy_stream(file, tempfile) }
    end
    tempfile.rewind
    tempfile
  end

  def replace_attachment_file(output_file, format_config)
    filename = "#{File.basename(@attachment.file.filename.to_s, '.*')}.#{format_config[:extension]}"
    @attachment.file.attach(
      io: File.open(output_file.path),
      filename: filename,
      content_type: format_config[:content_type]
    )
    @attachment.file_type = :audio
  end
end

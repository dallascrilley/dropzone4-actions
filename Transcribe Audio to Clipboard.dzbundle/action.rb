# Dropzone Action Info
# Name: Transcribe Audio to Clipboard
# Description: Drop one or more audio files (MP3, WAV, M4A) or MP4 video files to send them to Deepgram for transcription. For MP4 files, the audio is extracted as a 128kbps MP3 before sending.
# Handles: Files
# Creator: Dallas Crilley
# URL: https://dallascrilley.com
# Events: Dragged
# SkipConfig: Yes
# RunsSandboxed: No
# Version: 1.1
# MinDropzoneVersion: 3.0

require 'json'
require 'tempfile'
require 'shellwords'

# Specify the full path to the ffmpeg binary.
FFMPEG_PATH = '/opt/homebrew/bin/ffmpeg'

# Transcribe a single file (audio or video) by sending its binary data to Deepgram.
def transcribe_file(file)
  # Deepgram API credentials and endpoint.
  api_token = "YOUR_DEEPGRAM_API_KEY"
  url       = "https://api.deepgram.com/v1/listen?model=nova-2&smart_format=true"
  
  # Determine the file extension.
  ext = File.extname(file).downcase.delete(".")
  
  if ext == "mp4"
    # For an MP4 file, extract the audio to a temporary MP3 file.
    original_path = File.expand_path(file)
    
    # Create a temporary file with a .mp3 extension.
    tmp_file = Tempfile.new(['deepgram_audio', '.mp3'])
    tmp_path = tmp_file.path
    tmp_file.close  # Close it so that ffmpeg can write to it.
    
    # Build the ffmpeg command using the full path.
    ffmpeg_command = "#{FFMPEG_PATH} -y -i #{Shellwords.escape(original_path)} -vn -ar 44100 -ac 2 -b:a 128k #{Shellwords.escape(tmp_path)}"
    
    # Run the ffmpeg command and capture its output.
    ffmpeg_output = `#{ffmpeg_command} 2>&1`
    unless $?.success?
      $dz.error("FFmpeg Error", "Failed to extract audio from video file: #{file}\nFFmpeg output:\n#{ffmpeg_output}")
      return nil
    end
    
    # Use the temporary MP3 file for transcription.
    file_path   = tmp_path
    content_type = "audio/mp3"
    
  else
    # Mapping file extensions to MIME content types for audio files.
    content_types = {
      "mp3" => "audio/mp3",
      "wav" => "audio/wav",
      "m4a" => "audio/m4a"
    }
    
    content_type = content_types[ext]
    unless content_type
      $dz.error("Error", "Unsupported file extension for transcription: .#{ext}")
      return nil
    end
    
    file_path = File.expand_path(file)
  end

  # Build the curl command. The --data-binary flag sends the actual audio file.
  curl_command = "curl --request POST " +
                 "--header 'Authorization: Token #{api_token}' " +
                 "--header 'Content-Type: #{content_type}' " +
                 "--data-binary @\"#{file_path}\" " +
                 "--url '#{url}'"
  
  response = `#{curl_command}`

  transcript = nil
  begin
    result = JSON.parse(response)
    
    if result["error"]
      $dz.error("Deepgram API Error", result["error"])
      transcript = nil
    elsif result["results"] &&
          result["results"]["channels"].is_a?(Array) &&
          !result["results"]["channels"].empty? &&
          result["results"]["channels"][0]["alternatives"].is_a?(Array) &&
          !result["results"]["channels"][0]["alternatives"].empty?
      transcript = result["results"]["channels"][0]["alternatives"][0]["transcript"]
    else
      $dz.error("Transcription Error", "Unexpected response structure:\n#{response}")
      transcript = nil
    end
  rescue JSON::ParserError => e
    $dz.error("Transcription Error", "Failed to parse JSON response:\n#{response}\nError: #{e}")
    transcript = nil
  end

  # If a temporary file was created (for MP4 conversion), delete it.
  if ext == "mp4" && File.exist?(file_path)
    File.delete(file_path)
  end

  transcript
end

def dragged
  $dz.begin("Sending file(s) to Deepgram for transcription...")
  transcripts = []

  $items.each do |item|
    if File.file?(item)
      transcript = transcribe_file(item)
      if transcript && !transcript.strip.empty?
        # Prepend the filename and newlines to the transcript.
        filename = File.basename(item)
        transcripts << "#{filename} Transcript\n\n#{transcript}"
      end
    else
      $dz.error("Error", "Skipping non-file item: #{item}")
    end
  end

  if transcripts.empty?
    $dz.error("Error", "No transcription was returned.")
  else
    final_text = transcripts.join("\n\n")
    # Copy the transcript(s) to the clipboard.
    IO.popen('pbcopy', 'w') { |clipboard| clipboard.puts final_text }
    $dz.finish("Transcription copied to clipboard")
  end

  $dz.url(false)
end
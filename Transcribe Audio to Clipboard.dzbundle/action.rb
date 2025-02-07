# Dropzone Action Info
# Name: Transcribe Audio to Clipboard
# Description: Drop one or more audio files (e.g. MP3) to send them to Deepgram for transcription. The returned transcript is copied to the clipboard.
# Handles: Files
# Creator: Dallas Crilley
# URL: https://dallascrilley.com
# Events: Dragged
# SkipConfig: Yes
# RunsSandboxed: No
# Version: 1.0
# MinDropzoneVersion: 3.0

require 'json'

# Transcribe a single audio file by sending its binary data to Deepgram.
def transcribe_file(file)
  # Deepgram API credentials and endpoint.
  api_token = "YOUR_DEEPGRAM_API_KEY"
  url       = "https://api.deepgram.com/v1/listen?model=nova-2&smart_format=true"
  
  # Mapping file extensions to MIME content types.
  content_types = {
    "mp3" => "audio/mp3",
    "wav" => "audio/wav",
    "m4a" => "audio/m4a"
  }
  
  # Determine the file extension (without the dot).
  ext = File.extname(file).downcase.delete(".")
  content_type = content_types[ext]
  
  unless content_type
    $dz.error("Error", "Unsupported file extension for transcription: .#{ext}")
    return nil
  end

  # Get the absolute file path.
  file_path = File.expand_path(file)
  
  # Build the curl command. The --data-binary flag sends the actual audio file.
  command = "curl --request POST " +
            "--header 'Authorization: Token #{api_token}' " +
            "--header 'Content-Type: #{content_type}' " +
            "--data-binary @\"#{file_path}\" " +
            "--url '#{url}'"
  
  # Execute the curl command and capture its output.
  response = `#{command}`

  begin
    result = JSON.parse(response)
    
    # Check for API error response.
    if result["error"]
      $dz.error("Deepgram API Error", result["error"])
      return nil
    end
    
    # Navigate the JSON response safely.
    if result["results"] &&
       result["results"]["channels"].is_a?(Array) &&
       !result["results"]["channels"].empty? &&
       result["results"]["channels"][0]["alternatives"].is_a?(Array) &&
       !result["results"]["channels"][0]["alternatives"].empty?
      
      transcript = result["results"]["channels"][0]["alternatives"][0]["transcript"]
      return transcript
    else
      $dz.error("Transcription Error", "Unexpected response structure:\n#{response}")
      return nil
    end
  rescue JSON::ParserError => e
    $dz.error("Transcription Error", "Failed to parse JSON response:\n#{response}\nError: #{e}")
    return nil
  end
end

def dragged
  $dz.begin("Sending audio file(s) to Deepgram for transcription...")
  transcripts = []

  $items.each do |item|
    if File.file?(item)
      transcript = transcribe_file(item)
      if transcript && !transcript.strip.empty?
        # Prepend the filename and newlines to the transcript
        filename = File.basename(item, ".*")
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
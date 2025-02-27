# Dropzone Action Info
# Name: Trim Video to Timestamp
# Description: Prompts for start/end timestamps (HH:MM:SS or seconds) and trims each dropped video file in-place.
# Handles: Files
# Creator: Dallas Crilley
# URL: https://dallascrilley.com
# Events: Dragged
# SkipConfig: Yes
# RunsSandboxed: No
# Version: 1.0
# MinDropzoneVersion: 3.0

require 'shellwords'

# Change this if your ffmpeg is in a different location:
FFMPEG_PATH = '/opt/homebrew/bin/ffmpeg'

def prompt_for_time(title)
  # Display a dialog and return just the "text returned" portion.
  # We'll wrap the AppleScript so we can parse the output easily.
  script = <<-APPLESCRIPT
    set userInput to text returned of (display dialog "#{title}" default answer "" buttons {"Cancel", "OK"} default button "OK" with title "#{title}")
    return userInput
  APPLESCRIPT

  raw_output = `osascript -e #{script.shellescape}`.strip
  # raw_output should be the user's text input or empty if canceled
  raw_output
end

def trim_video(input_file, start_time, end_time)
  original_path = File.expand_path(input_file)
  ext           = File.extname(original_path)
  base_name     = File.basename(original_path, ext)
  directory     = File.dirname(original_path)
  output_path   = File.join(directory, "#{base_name}_trimmed#{ext}")

  # Build FFmpeg command to trim.
  # Using copy for audio/video codecs to keep the same encoding and avoid re-encoding.
  # If you prefer re-encoding, remove `-c copy` and specify your codecs.
  cmd = [
    FFMPEG_PATH,
    '-y',            # overwrite output if it already exists
    '-i', Shellwords.escape(original_path),
    '-ss', Shellwords.escape(start_time),
    '-to', Shellwords.escape(end_time),
    '-c', 'copy',
    Shellwords.escape(output_path)
  ].join(' ')

  output = `#{cmd} 2>&1`
  unless $?.success?
    $dz.error("FFmpeg Error", "Failed to trim video:\n#{cmd}\n\nFFmpeg output:\n#{output}")
    return nil
  end

  output_path
end

def dragged
  # Prompt user for start/end times
  start_time = prompt_for_time("Enter the START time (HH:MM:SS or just seconds):")
  if start_time.empty?
    $dz.error("No Start Time", "You did not provide a start time.")
  end

  end_time = prompt_for_time("Enter the END time (HH:MM:SS or just seconds):")
  if end_time.empty?
    $dz.error("No End Time", "You did not provide an end time.")
  end

  $dz.begin("Trimming video(s)...")

  # Process each dragged item
  $items.each do |item|
    unless File.file?(item)
      $dz.error("Invalid File", "Skipping item (not a file): #{item}")
    end

    # Optionally, do a quick check if it's a video (by extension)
    ext = File.extname(item).downcase
    unless [".mp4", ".mov", ".mkv", ".avi", ".flv"].include?(ext)
      $dz.error("Unsupported File Type", "Only common video files are supported. Skipping: #{File.basename(item)}")
    end

    trimmed_output = trim_video(item, start_time, end_time)
    if trimmed_output
      puts "Trimmed file saved to: #{trimmed_output}"
    end
  end

  $dz.finish("Done trimming!")
  $dz.url(false)
end
# Dropzone Action Info
# Name: Convert Vertical Video to Landscape w/ Blurred BG
# Description: Converts vertical (9:16) video to 16:9 by centering it over a blurred background copy of itself.
# Handles: Files
# Creator: Dallas
# URL: https://dallascrilley.com
# Events: Dragged
# SkipConfig: Yes
# RunsSandboxed: No
# Version: 1.1
# MinDropzoneVersion: 3.0

require 'shellwords'

# Change this if your ffmpeg is in a different location:
FFMPEG_PATH = '/opt/homebrew/bin/ffmpeg'

def convert_video(input_file)
  original_path = File.expand_path(input_file)
  ext           = File.extname(original_path)
  base_name     = File.basename(original_path, ext)
  directory     = File.dirname(original_path)
  output_path   = File.join(directory, "#{base_name}_landscape#{ext}")

  # Filter breakdown:
  # 1) [0:v]scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,boxblur=40:20[bg]
  #    - Scale background to fill or exceed 1920x1080, then crop exactly 1920x1080, then blur.
  # 2) [0:v]scale=-2:1080:force_original_aspect_ratio=decrease[fg]
  #    - Scale the original vertical video so its height = 1080, width auto-adjusted (vertical stays vertical).
  # 3) overlay=(W-w)/2:(H-h)/2
  #    - Center the scaled foreground on the blurred background.
  cmd = [
    FFMPEG_PATH,
    '-y',  # Overwrite output if it exists
    '-i', Shellwords.escape(original_path),
    '-filter_complex',
    %Q("[0:v]scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,boxblur=40:20[bg];[0:v]scale=-2:1080:force_original_aspect_ratio=decrease[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2"),
    '-c:v', 'libx264',
    '-c:a', 'aac',
    '-b:a', '192k',
    '-movflags', '+faststart',
    '-pix_fmt', 'yuv420p',
    Shellwords.escape(output_path)
  ].join(' ')

  output = `#{cmd} 2>&1`
  unless $?.success?
    $dz.error("FFmpeg Error", "Failed to create blurred background video:\n#{cmd}\n\nFFmpeg output:\n#{output}")
    return nil
  end

  output_path
end

def dragged
  $dz.begin("Converting vertical videos to 16:9...")

  $items.each do |item|
    unless File.file?(item)
      $dz.error("Invalid File", "Skipping item (not a file): #{item}")
    end

    # (Optional) Quick extension check
    ext = File.extname(item).downcase
    unless [".mp4", ".mov", ".mkv", ".avi", ".flv"].include?(ext)
      $dz.error("Unsupported File Type", "Only common video files are supported. Skipping: #{File.basename(item)}")
    end

    new_file = convert_video(item)
    if new_file
      puts "Converted file saved to: #{new_file}"
    end
  end

  $dz.finish("Done converting!")
  $dz.url(false)
end
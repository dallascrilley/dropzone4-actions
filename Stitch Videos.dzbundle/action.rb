# filename: stitch_videos_dropzone_action.rb

# Dropzone Action Info
# Name: Stitch Videos
# Description: Combines multiple dropped video files into a single output video file (montage). Outputs to the source directory or Downloads.
# Handles: Files
# Creator: Dallas Crilley
# URL: https://dallascrilley.com
# Events: Dragged
# SkipConfig: Yes
# RunsSandboxed: No
# Version: 2.3
# MinDropzoneVersion: 4.0

require 'shellwords'
require 'pathname'
require 'time'
require 'tmpdir'

# --- Configuration ---
FFMPEG_PATH = '/opt/homebrew/bin/ffmpeg'
FFPROBE_PATH = '/opt/homebrew/bin/ffprobe' # Added for audio detection
FALLBACK_OUTPUT_DIR = File.expand_path("~/Downloads")
DEFAULT_FILENAME_PREFIX = "video_montage"
DEFAULT_OUTPUT_EXT = ".mp4"
FFMPEG_ENCODE_OPTS = "-c:v libx264 -preset medium -crf 23 -c:a aac -b:a 128k"
# --- End Configuration ---

# Helper function to escape strings for AppleScript
def escape_for_applescript_string(str)
  str.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
end

# Helper function to prompt for output filename
def prompt_for_output_filename(default_filename, default_dir_path)
  if default_dir_path == FALLBACK_OUTPUT_DIR && !Dir.exist?(default_dir_path)
    begin
      Dir.mkdir(default_dir_path)
      puts("Created fallback directory: #{default_dir_path}")
    rescue => e
      $dz.error("Directory Error", "Could not create fallback directory: #{default_dir_path}\nError: #{e.message}")
      return ""
    end
  elsif !Dir.exist?(default_dir_path)
    $dz.error("Directory Error", "Default output directory does not exist: #{default_dir_path}")
    return ""
  end

  escaped_filename = escape_for_applescript_string(default_filename)
  escaped_dir_path = escape_for_applescript_string(default_dir_path)

  script = <<-APPLESCRIPT
    set defaultFileName to "#{escaped_filename}"
    set defaultLocationPath to "#{escaped_dir_path}"
    try
      set defaultLocationAlias to (POSIX file defaultLocationPath) as alias
      tell application "System Events" to activate
      set chosenFile to choose file name with prompt "Choose a name and location for the stitched video:" default name defaultFileName default location defaultLocationAlias
      return POSIX path of chosenFile
    on error errMsg number errNum
      if errNum is -128 then
        return ""
      else
        return "applescript_error:" & errNum & ":" & errMsg
      end if
    end try
  APPLESCRIPT

  raw_output = `osascript -e #{script.shellescape}`.strip

  if raw_output.start_with?("applescript_error:")
    error_details = raw_output.split(":", 3)
    err_num = error_details[1] || "Unknown"
    err_msg = error_details[2] || "No message"
    $dz.error("AppleScript Error", "Failed to get output filename.\nError Code: #{err_num}\nMessage: #{err_msg}")
    return ""
  elsif raw_output.empty?
    puts("User canceled save dialog.")
    return ""
  end

  output_path = raw_output
  output_path_pn = Pathname.new(output_path)
  if output_path_pn.extname.empty? || output_path_pn.extname.downcase != DEFAULT_OUTPUT_EXT.downcase
    output_path = output_path_pn.sub_ext(DEFAULT_OUTPUT_EXT).to_s
    puts("Adjusted output filename to ensure correct extension: #{File.basename(output_path)}")
  end

  output_path
end

def dragged
  $dz.begin("Preparing to stitch videos...")

  # 1. Filter dropped items
  valid_video_files = []
  allowed_extensions = [".mp4", ".mov", ".mkv", ".avi", ".flv", ".wmv", ".webm", ".mpeg", ".mpg"]

  $items.each do |item|
    unless File.file?(item)
      puts("Skipping item (not a file): #{item}")
      next
    end

    ext = File.extname(item).downcase
    if allowed_extensions.include?(ext)
      valid_video_files << item
    else
      puts("Skipping item (not a recognized video type): #{File.basename(item)}")
    end
  end

  valid_video_files.sort!
  puts "Found #{valid_video_files.count} valid video files to process:"
  valid_video_files.each { |f| puts "- #{File.basename(f)}" }

  # 2. Check if we have enough videos
  unless valid_video_files.count >= 1
    $dz.error("No Valid Videos", "Please drop at least one recognized video file.")
    $dz.finish("Stitching Canceled")
    $dz.url(false)
    return
  end

  if valid_video_files.count == 1
    puts("Warning: Only one video file dropped. The output will be a re-encoded version of this single file.")
  end

  # 3. Determine output directory and prompt for filename
  output_dir = FALLBACK_OUTPUT_DIR
  if valid_video_files.any?
    first_video_path = valid_video_files.first
    begin
      output_dir = Pathname.new(first_video_path).dirname.realpath.to_s
    rescue => e
      puts("Warning: Could not determine directory of first video '#{first_video_path}'. Falling back to Downloads. Error: #{e.message}")
      output_dir = FALLBACK_OUTPUT_DIR
    end
  end

  timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
  default_filename = "#{DEFAULT_FILENAME_PREFIX}_#{timestamp}#{DEFAULT_OUTPUT_EXT}"
  output_path = prompt_for_output_filename(default_filename, output_dir)

  if output_path.empty?
    $dz.finish("Stitching Canceled")
    $dz.url(false)
    return
  end

  output_path_dir = File.dirname(output_path)
  unless File.writable?(output_path_dir)
    $dz.error("Permissions Error", "The output directory is not writable: #{output_path_dir}")
    $dz.finish("Stitching Failed")
    $dz.url(false)
    return
  end

  $dz.begin("Stitching #{valid_video_files.count} video(s)...")
  $dz.determinate(false)

  # 4. Create intermediate files
  intermediate_dir = Dir.mktmpdir("dz_stitch_videos")
  begin
    intermediate_files = []
    valid_video_files.each_with_index do |video_file, index|
      # Check for audio presence
      has_audio = !`#{FFPROBE_PATH} -i #{Shellwords.escape(video_file)} -show_streams -select_streams a -loglevel error`.strip.empty?
      intermediate_file = File.join(intermediate_dir, "intermediate_#{index}.mp4")
      
      cmd = if has_audio
        [
          FFMPEG_PATH,
          '-i', video_file,
          '-vf', "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,format=yuv420p",
          '-r', '25',
          '-af', "aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo",
          *FFMPEG_ENCODE_OPTS.split,
          '-map', '0:v:0',
          '-map', '0:a:0',
          '-y',
          intermediate_file
        ]
      else
        [
          FFMPEG_PATH,
          '-i', video_file,
          '-f', 'lavfi',
          '-i', 'anullsrc=channel_layout=stereo:sample_rate=48000',
          '-vf', "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,format=yuv420p",
          '-r', '25',
          *FFMPEG_ENCODE_OPTS.split,
          '-map', '0:v:0',
          '-map', '1:a:0',
          '-shortest',
          '-y',
          intermediate_file
        ]
      end

      puts "Creating intermediate file for #{File.basename(video_file)}..."
      system(*cmd)
      if $?.success?
        intermediate_files << intermediate_file
      else
        puts "Failed to create intermediate file for #{video_file}"
      end
    end

    if intermediate_files.empty?
      $dz.error("Processing Error", "None of the videos could be processed into intermediate files.")
      $dz.finish("Stitching Failed")
      $dz.url(false)
      return
    end

    # 5. Create concat list file
    temp_list_path = File.join(ENV['TMPDIR'] || '/tmp', "dz_concat_list_#{Process.pid}.txt")
    File.open(temp_list_path, 'w') do |f|
      intermediate_files.each do |file|
        escaped = file.gsub("'", "'\\\\\\''")
        f.puts "file '#{escaped}'"
      end
    end
    puts "--- Temporary List File Contents (#{temp_list_path}) ---"
    puts File.read(temp_list_path)
    puts "----------------------------------------------------"

    # 6. Concatenate
    cmd_array = [
      FFMPEG_PATH,
      '-y',
      '-f', 'concat',
      '-safe', '0',
      '-i', temp_list_path,
      '-c', 'copy',
      output_path
    ]
    puts "Running FFmpeg concatenation command..."
    puts "Command array: #{cmd_array.inspect}"

    start_time = Time.now
    ffmpeg_output = ""
    IO.popen(cmd_array, err: [:child, :out]) do |pipe|
      pipe.each_line { |line| ffmpeg_output += line }
    end
    success = $?.success?
    end_time = Time.now

    puts "--- FFmpeg Concatenation Output (Success=#{success}) ---"
    puts ffmpeg_output
    puts "---------------------------------------"

    File.delete(temp_list_path) if File.exist?(temp_list_path)
  ensure
    intermediate_files.each { |file| File.delete(file) if File.exist?(file) }
    Dir.delete(intermediate_dir) if Dir.exist?(intermediate_dir)
  end

  # 7. Provide feedback
  if success
    duration = Time.at(end_time - start_time).utc.strftime("%H:%M:%S")
    $dz.finish("Video Stitched Successfully! (#{duration})")
    escaped_url_path = Shellwords.escape(output_path).gsub('+', '%20')
    $dz.url("file://#{escaped_url_path}")
  else
    $dz.error("FFmpeg Error", "Failed to stitch videos. See Action Console log for FFmpeg output.")
    $dz.finish("Stitching Failed")
    $dz.url(false)
  end
end
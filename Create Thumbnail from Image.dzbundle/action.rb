# Dropzone Action Info
# Name: Create Thumbnail from Image
# Description: Uses ImageMagick to resize images so the longest side is max 1920, then pads to 1920×1080.
# Handles: Files
# Creator: Dallas Crilley
# URL: https://dallascrilley.com
# Events: Dragged
# SkipConfig: Yes
# RunsSandboxed: No
# Version: 1.3
# MinDropzoneVersion: 3.0

require 'open3'

def dragged
  puts "Starting the Dropzone action..."

  $dz.begin("Resizing & padding images with chosen background...")
  $dz.determinate(true)

  allowed_exts = %w[jpg jpeg png]

  if $items.empty?
    puts "No items dragged in. Exiting."
    $dz.finish("No files were provided.")
    return
  end

  # Prompt the user for the background color. Defaults to black if empty.
  bg_color = $dz.inputbox(
    "Background Color",
    "Enter a color name (e.g. black, red, white) or a hex code (e.g. #000000). Leave blank for black.",
    "black"
  )
  bg_color = bg_color.strip
  bg_color = "black" if bg_color.empty?

  total = $items.length
  processed = 0
  puts "Number of items: #{total}"

  # Path to your magick binary (adjust if needed)
  magick_path = "/opt/homebrew/bin/magick"

  $items.each do |filepath|
    puts "Processing file: #{filepath.inspect}"

    # e.g. ".jpg" -> "jpg"
    raw_ext    = File.extname(filepath).downcase
    extension  = raw_ext.sub('.', '') # remove leading '.'

    unless allowed_exts.include?(extension)
      msg = "Unsupported file type: #{extension}"
      puts msg
      $dz.error("Error", msg)
    end

    # Safely get the base name without *any* extension
    basename = File.basename(filepath, raw_ext) # e.g. "Xn_Zx.qR4e.1 (1)"

    # Construct the output path, e.g. /path/to/Xn_Zx.qR4e.1 (1)_thumbnail@1920x1080.jpg
    dirname = File.dirname(filepath)
    outpath = File.join(dirname, "#{basename}_thumbnail@1920x1080.#{extension}")
    puts "Output path: #{outpath.inspect}"

    # 1. Resize so no dimension exceeds 1920 (maintains aspect ratio)
    # 2. Pad/extent to exactly 1920x1080 (centered) with background color
    cmd = [
      magick_path,
      filepath,
      "-resize", "1920x1920>",   # constraint so the longest side is 1920 max
      "-background", bg_color,
      "-gravity", "center",
      "-extent", "1920x1080",
      outpath
    ]
    puts "Running command:\n  #{cmd.join(' ')}"

    # Capture all output (stdout & stderr)
    output, status = Open3.capture2e(*cmd)
    puts "Command output:\n#{output}"

    unless status.success?
      $dz.error("ImageMagick Error", "The convert command failed. Output:\n#{output}")
    end

    processed += 1
    $dz.percent((processed.to_f / total) * 100.0)
  end

  puts "Finished processing all files."
  $dz.finish("All images resized/padded to 1920×1080 using background: #{bg_color}")
  $dz.url(false)
end
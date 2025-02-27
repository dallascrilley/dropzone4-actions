# Dropzone Action Info
# Name: Create Thumbnail from Image / Overlay Image on Background
# Description: Uses ImageMagick to resize images so the longest side is max 1920, then pads to 1920×1080.
# Handles: Files
# Creator: Dallas Crilley
# URL: https://dallascrilley.com
# Events: Dragged
# SkipConfig: Yes
# RunsSandboxed: No
# Version: 1.4
# MinDropzoneVersion: 3.0

require 'open3'

# Simple map of base Bootstrap color tokens to their "500" hex code.
BASE_COLORS = {
  "$blue"   => "#0d6efd",
  "$indigo" => "#6610f2",
  "$purple" => "#6f42c1",
  "$pink"   => "#d63384",
  "$red"    => "#dc3545",
  "$orange" => "#fd7e14",
  "$yellow" => "#ffc107",
  "$green"  => "#198754",
  "$teal"   => "#20c997",
  "$cyan"   => "#0dcaf0",
  "$gray"   => "#adb5bd",
  "$black"  => "#000",
  "$white"  => "#fff"
}

# Mapping for numeric suffix -> lighten/darken operation + ratio
# Example interpretation:
#  - 100 => lighten by 90%
#  - 900 => darken by 40%
SHADES = {
  100 => [:lighten, 0.90],
  200 => [:lighten, 0.75],
  300 => [:lighten, 0.60],
  400 => [:lighten, 0.45],
  500 => [:none,    0.00], # same as base
  600 => [:darken,  0.10],
  700 => [:darken,  0.20],
  800 => [:darken,  0.30],
  900 => [:darken,  0.40]
}

###
# Helper: Parse a #RRGGBB hex string into [r, g, b].
###
def parse_hex_color(hex_str)
  hex = hex_str.gsub(/^#/, '')
  # If short (#abc), expand to (#aabbcc) if needed.
  hex = hex.chars.map { |c| [c, c] }.flatten.join if hex.size == 3
  r = hex[0..1].to_i(16)
  g = hex[2..3].to_i(16)
  b = hex[4..5].to_i(16)
  [r, g, b]
end

###
# Helper: Convert [r,g,b] => "#rrggbb"
###
def to_hex_color(rgb)
  "#%02x%02x%02x" % rgb
end

###
# Helper: Mix two [r,g,b] arrays by ratio (0..1).
# ratio=0 => c1; ratio=1 => c2
###
def mix_colors(c1, c2, ratio)
  r = (c1[0] + (c2[0] - c1[0]) * ratio).round
  g = (c1[1] + (c2[1] - c1[1]) * ratio).round
  b = (c1[2] + (c2[2] - c1[2]) * ratio).round
  [r, g, b]
end

###
# Given a color string, return a hex code if recognized as:
#   - "#abc" or "#rrggbb"
#   - A plain word like "black", "red", etc. (ImageMagick should accept these)
#   - A bootstrap token like "$blue", "$blue-100", "$red-900"
# Else, returns the original string (ImageMagick might handle it, or fail).
###
def interpret_color(input_color)
  color = input_color.strip

  # If it starts with '#' => user typed raw hex -> pass through
  return color if color.match(/^#([\h]{3}|[\h]{6})$/i)

  # If it doesn't start with '$', pass color directly (e.g. "black", "red")
  return color unless color.start_with?('$')

  # Now handle a bootstrap token: "$blue" / "$blue-500" / "$blue-100"
  # 1. Extract base token: "$blue"
  # 2. Extract numeric suffix: "100" or "500" or "900"
  # If no suffix, default to 500.
  if color.match(/^(\$\w+)(-(\d{3}))?$/)
    base_token = Regexp.last_match(1) # e.g. "$blue"
    suffix_str = Regexp.last_match(3) # e.g. "100" or nil

    # If base is recognized, get its hex
    base_hex = BASE_COLORS[base_token]
    return color unless base_hex # not recognized -> fallback

    # Suffix defaults to 500 if none provided
    suffix_num = suffix_str ? suffix_str.to_i : 500

    shade_op, ratio = SHADES[suffix_num]
    base_rgb = parse_hex_color(base_hex)

    case shade_op
    when :lighten
      # lighten by mixing with white
      lighter_rgb = mix_colors(base_rgb, [255, 255, 255], ratio)
      return to_hex_color(lighter_rgb)
    when :darken
      # darken by mixing with black
      darker_rgb = mix_colors(base_rgb, [0, 0, 0], ratio)
      return to_hex_color(darker_rgb)
    else
      # 500 or unknown => the base color
      return base_hex
    end
  end

  # If somehow it doesn't match the above pattern, just return raw string.
  color
end

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
  input_color = $dz.inputbox(
    "Background Color",
    "Enter a CSS color name, hex code (#fff), or a Bootstrap token ($blue-300). Leave blank for black.",
    "black"
  )
  # Convert user input to a final hex or color name we can safely use
  bg_color = interpret_color(input_color)
  bg_color = "black" if bg_color.strip.empty?

  total = $items.length
  processed = 0
  puts "Number of items: #{total}"

  # Path to your magick binary (adjust if needed)
  magick_path = "/opt/homebrew/bin/magick"

  $items.each do |filepath|
    puts "Processing file: #{filepath.inspect}"

    raw_ext    = File.extname(filepath).downcase
    extension  = raw_ext.sub('.', '') # remove leading '.'

    unless allowed_exts.include?(extension)
      msg = "Unsupported file type: #{extension}"
      puts msg
      $dz.error("Error", msg)
    end

    basename = File.basename(filepath, raw_ext)
    dirname  = File.dirname(filepath)
    outpath  = File.join(dirname, "#{basename}_thumbnail@1920x1080.#{extension}")
    puts "Output path: #{outpath.inspect}"

    # 1. Resize so no dimension exceeds 1920 (maintains aspect ratio)
    # 2. Pad/extent to exactly 1920x1080 (centered) with background color
    cmd = [
      magick_path,
      filepath,
      "-resize", "1920x1920>",
      "-background", bg_color,
      "-gravity", "center",
      "-extent", "1920x1080",
      outpath
    ]
    puts "Running command:\n  #{cmd.join(' ')}"

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
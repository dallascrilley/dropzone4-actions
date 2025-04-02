# Dropzone Action Info
# Name: Resize Image to User Defined Size
# Description: Prompt for max dimension, resize proportionally using built-in Mac commands
# Handles: Files
# Creator: Dallas Crilley
# URL: https://dallascrilley.com
# Events: Dragged
# SkipConfig: Yes
# RunsSandboxed: No
# Version: 1.1
# MinDropzoneVersion: 3.0

def dragged
  standard_types = ["jpg", "jpeg", "png"]

  max_dimension = $dz.inputbox("Enter Maximum Dimension", "Enter maximum width or height in pixels:", "1024")

  unless max_dimension =~ /^\d+$/
    $dz.error("Invalid Input", "Please enter a valid integer for the maximum dimension.")
  end

  max_dimension = max_dimension.to_i

  $dz.begin("Resizing images...")
  $dz.determinate(true)

  num_processed = 0

  $items.each do |item|
    extension = File.extname(item).downcase[1..-1]
    basename = File.basename(item, ".#{extension}")
    dirname = File.dirname(item)

    unless standard_types.include?(extension)
      $dz.error("Unsupported File", "Only JPG and PNG files are supported.")
      next
    end

    output_file = File.join(dirname, "#{basename}-resized.#{extension}")

    resize_command = "sips --resampleHeightWidthMax #{max_dimension} \"#{item}\" --out \"#{output_file}\" 2>&1"
    output = `#{resize_command}`

    if $?.exitstatus != 0
      $dz.error("Error resizing", output)
    end

    num_processed += 1
    $dz.percent((num_processed.to_f / $items.length) * 100.0)
  end

  $dz.finish("Resizing complete!")
  $dz.url(false)
end
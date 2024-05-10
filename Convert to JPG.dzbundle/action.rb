# Dropzone Action Info
# Name: Convert to JPG
# Description: Convert a dropped image to JPG. Uses built-in Mac Commands. No prerequisites to install.
# Handles: Files
# Creator: Dallas Crilley
# URL: https://dallascrilley.com
# Events: Dragged
# SkipConfig: Yes
# RunsSandboxed: No
# Version: 1.0
# MinDropzoneVersion: 3.0

def dragged
  supported_types = ["jpg", "jpeg", "png", "webp", "gif"]  # Extendable list of image extensions.
  $dz.begin("Running task...")
  $dz.determinate(true)
  num = 0
  $items.each do |item|
    extension = File.extname(item).downcase[1..-1]
    if supported_types.include?(extension)
      new_filename = "#{File.basename(item, '.*')}.jpg"
      output_path = File.join(File.dirname(item), new_filename)
      `sips -s format jpeg \"#{item}\" --out \"#{output_path}\" 2>&1`
    else
      $dz.error("Error", "Supported formats: JPG, JPEG, PNG, WEBP, GIF") # Extendable list of file extensions.
    end
    num += 1
    $dz.percent((num.to_f/$items.length)*100.0)
  end
  $dz.finish("Conversion complete")
  $dz.url(false)
end

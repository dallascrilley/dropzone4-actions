# Dropzone Action Info
# Name: Copy Text and Code Files to Clipboard
# Description: Drop one or more text or code files to copy their contents to the clipboard with a new line separator between files.
# Handles: Files
# Creator: Dallas Crilley
# URL: https://dallascrilley.com
# Events: Dragged
# SkipConfig: Yes
# RunsSandboxed: No
# Version: 1.0
# MinDropzoneVersion: 3.0

def dragged
  text_types = ["txt", "js", "py", "html", "htm", "css", "md", "java", "c", "cpp", "cs", "rb", "swift", "kt", "php", "pl", "ts", "sh", "xml", "yaml", "yml", "json", "ini", "toml", "properties", "csv", "tsv", "sql", "rtf", "tex", "less", "sass", "scss", "ps1", "bat", "cmd", "Dockerfile", "Makefile", "gradle"]  # Extendable list of file extensions.
  
  $dz.begin("Copying files to clipboard...")
  $dz.determinate(true)

  file_contents = []
  $items.each do |item|
    extension = File.extname(item).downcase[1..-1]
    if text_types.include?(extension)
      content = File.read(item)
      file_contents << content
    else
      $dz.error("Error", "Unsupported file type: #{extension}")
    end
  end

  clipboard_content = file_contents.join("\n")
  IO.popen('pbcopy', 'w') { |clipboard| clipboard.puts clipboard_content }

  $dz.finish("Files copied to clipboard")
  $dz.url(false)
end
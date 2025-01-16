# Dropzone Action Info
# Name: Copy Text and Code Files to Clipboard
# Description: Drop one or more text or code files to copy their contents to the clipboard with a new line separator between files.
# Handles: Files
# Creator: Dallas Crilley
# URL: https://dallascrilley.com
# Events: Dragged
# SkipConfig: Yes
# RunsSandboxed: No
# Version: 1.1
# MinDropzoneVersion: 3.0

def process_file(file, file_contents, text_types)
  # Extract the extension without the dot and downcase it
  raw_extension = File.extname(file).downcase
  extension = raw_extension.length > 1 ? raw_extension[1..-1] : ''

  if text_types.include?(extension)
    # File has a supported extension
    process_as_text(file, file_contents)
  elsif extension.empty?
    # File has no extension
    process_as_text(file, file_contents)
  else
    # Determine if the extension should be ignored (treated as no extension)
    # For example, treat extensions with non-alphanumeric characters as no extension
    if extension.match?(/^[a-z0-9]+$/i)
      # Extension is purely alphanumeric but not in text_types; treat as unsupported
      $dz.error("Unsupported File Type", "File #{file} has an unsupported file type: #{extension}")
    else
      # Extension contains non-alphanumeric characters; treat as no extension
      process_as_text(file, file_contents)
    end
  end
end

def process_as_text(file, file_contents)
  begin
    content = File.read(file)
    parent_directory = File.dirname(file)
    truncated_path = truncate_path(parent_directory)
    filename = File.basename(file)
    file_contents << "// #{truncated_path}/#{filename}\n#{content}"
  rescue => e
    $dz.error("Error Reading File", "Could not read #{file}: #{e.message}")
  end
end

def truncate_path(path)
  # Split the path into directories
  parts = path.split(File::SEPARATOR)
  # Take the last two directories
  truncated_parts = parts.last(2)
  # Join them back with the file separator
  truncated_path = truncated_parts.join(File::SEPARATOR)
  truncated_path
end

def process_directory(directory, file_contents, text_types)
  Dir.glob("#{directory}/**/*").each do |file|
    process_file(file, file_contents, text_types) if File.file?(file)
  end
end

def dragged
  text_types = [
    "txt", "js", "py", "html", "htm", "css", "md", "java", "c",
    "cpp", "cs", "rb", "swift", "kt", "php", "pl", "ts", "sh",
    "xml", "yaml", "yml", "json", "ini", "toml", "properties",
    "csv", "tsv", "sql", "rtf", "tex", "tsx", "less", "sass",
    "scss", "ps1", "bat", "cmd", "Dockerfile", "Makefile",
    "gradle", "log" # Extendable list of file extensions.
  ]
  
  $dz.begin("Copying files to clipboard...")
  $dz.determinate(true)

  file_contents = []
  $items.each do |item|
    if File.directory?(item)
      process_directory(item, file_contents, text_types)
    else
      process_file(item, file_contents, text_types)
    end
  end

  clipboard_content = file_contents.join("\n")
  
  begin
    IO.popen('pbcopy', 'w') { |clipboard| clipboard.puts clipboard_content }
    $dz.finish("Files copied to clipboard")
  rescue => e
    $dz.error("Clipboard Error", "Failed to copy to clipboard: #{e.message}")
  end
  
  $dz.url(false)
end

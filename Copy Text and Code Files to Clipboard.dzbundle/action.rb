# Dropzone Action Info
# Name: Copy Text and Code Files to Clipboard
# Description: Drop one or more text or code files to copy their contents to the clipboard with a new line separator between files.
# Handles: Files
# Creator: Dallas Crilley
# URL: https://dallascrilley.com
# Events: Dragged
# SkipConfig: Yes
# RunsSandboxed: No
# Version: 1.5
# MinDropzoneVersion: 3.0

# A list of regex patterns for directory or file names to ignore.
IGNORED_PATTERNS = [
  /^node_modules$/i,
  /^venv$/i,
  /^\.venv$/i,
  /^\.git$/i,
  /^\.svn$/i,
  /^\.hg$/i,
  /^\.idea$/i,
  /^dist$/i,
  /^build$/i,
  /^tmp$/i,
  /^cache$/i,
  /^\.ds_store$/i,
  /^thumbs\.db$/i,
  /pycache/i  # This pattern will match any variation that contains "pycache"
]

# Grouping of file extensions by comment tokens.
# Each element is an array where the first element is a regex that matches one or more file extensions,
# and the second element is an array with the comment start and end tokens.
COMMENT_TOKEN_GROUPS = [
  # Plain text files: use hash-based comment tokens.
  [ /^(txt)$/i,                        ["# ", ""] ],

  # Hash-based comments (e.g. Python, Ruby, Shell, Perl, PowerShell, YAML, TOML, .properties).
  [ /^(py|rb|sh|pl|ps1|yaml|yml|toml|properties|txt)$/i, ["# ", ""] ],

  # HTML-style comments (for HTML, XML, and Markdown files).
  [ /^(html?|xml|md)$/i,                ["<!-- ", " -->"] ],

  # C-style single-line comments (for Java, C, C++, C#, Swift, Kotlin, PHP, Less, Sass, SCSS, Gradle, Log files, and JavaScript).
  [ /^(java|c|cpp|cs|swift|kt|php|less|sass|scss|gradle|log|js)$/i, ["// ", ""] ],

  # Block comment style (for TypeScript and JSX files).
  [ /^(jsx|tsx|ts)$/i,                 ["/* ", " */"] ],

  # SQL-style comments.
  [ /^(sql)$/i,                        ["-- ", ""] ],

  # INI-style comments (commonly used in INI files).
  [ /^(ini)$/i,                        ["; ", ""] ],

  # Files with no official comment style (for JSON, CSV, TSV, or RTF we use a simple double-slash).
  [ /^(json|csv|tsv|rtf)$/i,             ["// ", ""] ],

  # LaTeX files use the percent sign.
  [ /^(tex)$/i,                        ["% ", ""] ],

  # Batch files use the REM keyword.
  [ /^(bat|cmd)$/i,                    ["REM ", ""] ]
]
# Default comment tokens if no group matches.
DEFAULT_COMMENT_TOKENS = ["// ", ""]

def ignore_path?(path)
  # Split the path into components and check if any match the ignored patterns.
  path.split(File::SEPARATOR).any? do |part|
    IGNORED_PATTERNS.any? { |pattern| pattern.match?(part) }
  end
end

def process_file(file, file_contents, text_types)
  # Skip the file if it is in an ignored directory.
  return if ignore_path?(file)

  # Extract the extension without the dot and downcase it.
  raw_extension = File.extname(file).downcase
  extension = raw_extension.length > 1 ? raw_extension[1..-1] : ''

  if text_types.include?(extension)
    # File has a supported extension.
    process_as_text(file, file_contents)
  elsif extension.empty?
    # File has no extension.
    process_as_text(file, file_contents)
  else
    # For alphanumeric extensions not in our list, treat as unsupported.
    if extension.match?(/^[a-z0-9]+$/i)
      $dz.error("Unsupported File Type", "File #{file} has an unsupported file type: #{extension}")
    else
      # Extensions with non-alphanumeric characters are processed as text.
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

    # Determine the file extension (without the dot).
    ext = File.extname(file).downcase.sub('.', '')
    
    # Find the comment tokens based on the extension using our grouped regex.
    comment_tokens = COMMENT_TOKEN_GROUPS.find { |pattern, _| ext.match?(pattern) }
    comment_start, comment_end = comment_tokens ? comment_tokens[1] : DEFAULT_COMMENT_TOKENS
    
    # Build the header comment.
    header = if comment_end.empty?
               "#{comment_start}#{truncated_path}/#{filename}"
             else
               "#{comment_start}#{truncated_path}/#{filename}#{comment_end}"
             end

    # Build the footer comment.
    footer = if comment_end.empty?
               "#{comment_start}End of file: #{filename}"
             else
               "#{comment_start}End of file: #{filename}#{comment_end}"
             end

    # Append header, content, and footer (separated by newlines).
    file_contents << "#{header}\n\n#{content}\n\n#{footer}\n\n"
  rescue => e
    $dz.error("Error Reading File", "Could not read #{file}: #{e.message}")
  end
end

def truncate_path(path)
  # Split the path into directories.
  parts = path.split(File::SEPARATOR)
  # Take the last two directories.
  truncated_parts = parts.last(2)
  # Join them back using the file separator.
  truncated_parts.join(File::SEPARATOR)
end

def process_directory(directory, file_contents, text_types)
  # Skip processing if the directory itself should be ignored.
  return if ignore_path?(directory)

  Dir.glob("#{directory}/**/*").each do |file|
    # Skip any file whose path includes an ignored directory or file name.
    next if ignore_path?(file)
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
    "gradle", "log", "jsx", "tsx" # Extendable list of file extensions.
  ]
  
  $dz.begin("Copying files to clipboard...")
  $dz.determinate(true)

  file_contents = []
  $items.each do |item|
    # Skip the item if it is in an ignored directory or is an ignored file.
    next if ignore_path?(item)
    
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
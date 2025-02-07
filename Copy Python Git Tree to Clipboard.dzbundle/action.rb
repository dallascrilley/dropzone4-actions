# Dropzone Action Info
# Name: Copy Git File Tree to Clipboard (Python)
# Description: Recursively show Git-tracked files in a tree, along with Python class/def/route details and requirements.txt contents. Copies to clipboard.
# Handles: Files
# Creator: Dallas Crilley
# URL: https://dallascrilley.com
# Events: Dragged
# SkipConfig: Yes
# RunsSandboxed: No
# Version: 1.4
# MinDropzoneVersion: 3.0

require 'open3'

# -------------------------
#      CONFIG / CONSTANTS
# -------------------------
SKIP_DIRS = %w[__pycache__ venv .git alembic downloads ].freeze

# We'll accumulate lines of output here and then copy them all at once.
OUTPUT_LINES = []

# A small helper to capture lines in memory rather than printing.
def out(str)
  OUTPUT_LINES << str
end

# -------------------------
#         FUNCTIONS
# -------------------------

##
# Check if a file/directory is tracked by git
# Returns true if tracked, false otherwise.
def tracked_by_git?(path)
  # We only check real paths that exist on disk. If not exist, skip.
  return false unless File.exist?(path)

  # Run: git ls-files --error-unmatch path
  # If exit code == 0, it is tracked.
  # If exit code != 0, it is untracked.
  cmd = ["git", "ls-files", "--error-unmatch", path]
  _stdout, _stderr, status = Open3.capture3(*cmd, chdir: File.dirname(path))
  status.success?
end

##
# Determine if a directory name is in the SKIP_DIRS array
def should_skip_dir?(dir_name)
  SKIP_DIRS.include?(dir_name)
end

##
# Print file contents of requirements.txt in a tree-like style
def show_requirements(file, prefix)
  return unless File.file?(file)

  lines = File.readlines(file, chomp: true)
  lines.each_with_index do |line, i|
    marker = (i == lines.size - 1) ? "└── " : "├── "
    out("#{prefix}#{marker}#{line}")
  end
end

##
# Extract Python details (classes, functions, routes) and print in tree-like style
def show_python_details(file, prefix)
  return unless File.file?(file)

  content = File.read(file)

  # --- Classes ---
  classes = content.scan(/^[[:space:]]*class[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)/)
                   .map { |match| "class #{match[0]}" }

  # --- Functions ---
  funcs = content.scan(/^[[:space:]]*def[[:space:]]+([_a-zA-Z0-9]+)/)
                 .map { |match| "def #{match[0]}" }

  # --- Routes ---
  route_regex = /^[[:space:]]*@(app|router)\.(get|post|put|patch|delete)\(\s*["']([^"']+)/
  routes = content.scan(route_regex).map do |(_prefix, method, path)|
    "route #{method} #{path}"
  end

  # Combine them all and print with tree markers
  lines = classes + funcs + routes
  lines.each_with_index do |line_item, i|
    marker = (i == lines.size - 1) ? "└── " : "├── "
    out("#{prefix}#{marker}#{line_item}")
  end
end

##
# Recursively gather a tree of tracked files/directories
def show_tree(dir_path, prefix)
  return unless File.exist?(dir_path)

  children = Dir.children(dir_path).sort

  filtered = []
  children.each do |item|
    full_item = File.join(dir_path, item)

    if File.directory?(full_item)
      next if should_skip_dir?(item)

      if !tracked_by_git?(full_item)
        tracked_kid = Dir.glob("#{full_item}/**/*").any? { |p| tracked_by_git?(p) }
        next unless tracked_kid
      end
    else
      next unless tracked_by_git?(full_item)
    end

    filtered << item
  end

  filtered.each_with_index do |item, i|
    is_last = (i == filtered.size - 1)
    full_item = File.join(dir_path, item)

    marker = is_last ? "└── " : "├── "
    continuation = is_last ? (prefix + "    ") : (prefix + "│   ")

    out("#{prefix}#{marker}#{item}")

    if File.directory?(full_item)
      show_tree(full_item, continuation)
    else
      if item.end_with?(".py")
        show_python_details(full_item, continuation)
      elsif item == "requirements.txt"
        show_requirements(full_item, continuation)
      end
    end
  end
end

# -------------------------
#       DROPZONE HOOK
# -------------------------
def dragged
  $dz.begin("Generating Git tree and copying to clipboard...")
  $dz.determinate(true)

  OUTPUT_LINES.clear
  out(".")

  $items.each do |path|
    if File.directory?(path)
      show_tree(path, "")
    else
      parent = File.dirname(path)
      show_tree(parent, "")
    end
  end

  clipboard_content = OUTPUT_LINES.join("\n")

  begin
    IO.popen('pbcopy', 'w') { |clipboard| clipboard.puts clipboard_content }
    $dz.finish("Tree copied to clipboard!")
  rescue => e
    $dz.error("Clipboard Error", "Failed to copy to clipboard: #{e.message}")
  end

  $dz.url(false)
end

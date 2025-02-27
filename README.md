# Dropzone 4 Actions

A collection of custom actions I've written for Dropzone3/4 that I've needed and found useful to increase my productivity. I'll continue adding to this as I make them.

## Available Actions

### 1. Convert to JPG
This action allows users to quickly convert a dropped image to JPG format using built-in Mac commands, with no prerequisites to install.

- **Name**: Convert to JPG
- **Description**: Convert a dropped image to JPG using built-in Mac commands.
- **Handles**: Files
- **Creator**: Dallas Crilley
- **URL**: [dallascrilley.com](https://dallascrilley.com)
- **Events**: Dragged
- **SkipConfig**: Yes
- **RunsSandboxed**: No
- **Version**: 1.0
- **MinDropzoneVersion**: 3.0

#### Supported Image Formats:
- JPG, JPEG, PNG, WEBP, GIF

#### Example Usage:

1. Drag and drop a supported image file onto the action.
2. The file will be converted to a `.jpg` format, replacing or creating a new file in the same directory.
3. If the file type is unsupported, an error message will be displayed.

---

### 2. Copy Text and Code Files to Clipboard
This action lets you copy the contents of one or more text or code files to the clipboard, with a newline separating the contents of different files.

- **Name**: Copy Text and Code Files to Clipboard
- **Description**: Copy contents of dropped text/code files to the clipboard, separated by start and end comments containing the file name and path.
- **Handles**: Files
- **Creator**: Dallas Crilley
- **URL**: [dallascrilley.com](https://dallascrilley.com)
- **Events**: Dragged
- **SkipConfig**: Yes
- **RunsSandboxed**: No
- **Version**: 1.0
- **MinDropzoneVersion**: 3.0

#### Supported File Types:
This action supports a broad range of text and code files. In addition to the common types, it now supports many more file types, each handled with the appropriate comment tokens:

- Text Files: `txt`, `md`, `rtf`
- Code Files: `js`, `py`, `html`, `css`, `java`, `cpp`, `php`, `ts`, and many more (full list included in the action).
- Build and configuration files: `Makefile`, `Dockerfile`, `gradle`, `log`, `properties`, `ini`, `json`, `csv`, `tsv`, `sql`, `tex`, `yaml`, `yml`

#### Example Usage:

1. Drag and drop one or more supported text/code files onto the action.
2. The contents of the files are read, wrapped with header and footer comments (including the file's relative path and name), and then concatenated together with a newline separating each file's contents.
3. If a file is unsupported or if an error occurs during processing (such as trying to read a binary file), an error message will appear.


---

### 3. Transcribe Audio and Video to Clipboard
This action allows users to quickly transcribe audio and video files, such as mp4, mp3, m4a, and wav, to text and copy the result to the clipboard. 

You will have to provide your own Deepgram API key and specify the path to the ffmpeg binary on your system.

- **Name**: Transcribe Audio and Video to Clipboard
- **Description**: Transcribe audio and video files to text and copy the result to the clipboard.
- **Handles**: Files
- **Creator**: Dallas Crilley
- **URL**: [dallascrilley.com](https://dallascrilley.com)
- **Events**: Dragged
- **SkipConfig**: Yes
- **RunsSandboxed**: No
- **Version**: 1.0
- **MinDropzoneVersion**: 3.0

### 4. Copy Git File Tree to Clipboard (Python)
This action recursively show Git-tracked files in a tree, along with Python class/def/route details and requirements.txt contents. Click and drag a Git-tracked folder onto the action and it will copy it to the clipboard.

Example output:
.
├── api
│   ├── routers
│   │   ├── __init__.py
│   │   ├── accounts_router.py
│   │   │   ├── def get_account_relationships
│   │   │   └── route get /accounts/{intermedia_account_id}/relationships

- **Name**: Transcribe Audio and Video to Clipboard
- **Description**: Transcribe audio and video files to text and copy the result to the clipboard.
- **Handles**: Files
- **Creator**: Dallas Crilley
- **URL**: [dallascrilley.com](https://dallascrilley.com)
- **Events**: Dragged
- **SkipConfig**: Yes
- **RunsSandboxed**: No
- **Version**: 1.0
- **MinDropzoneVersion**: 3.0


#### Example Usage:

1. Drag and a Git-tracked folder with Python code onto the action.
2. The .py files will be printed in a tree, along with the functions, classes, and routes it finds within. Non-python files will be included with their filenames but not the contents, with the exception of requirements.txt, since this is a useful file for context.

### 5. Trim Video to Timestamp
This action allows users to trim video files to specified start and end timestamps, modifying the files in place.

- **Name**: Trim Video to Timestamp
- **Description**: Prompts for start/end timestamps (HH:MM:SS or seconds) and trims each dropped video file in-place.
- **Handles**: Files
- **Creator**: Dallas Crilley
- **URL**: [dallascrilley.com](https://dallascrilley.com)
- **Events**: Dragged
- **SkipConfig**: Yes
- **RunsSandboxed**: No
- **Version**: 1.0
- **MinDropzoneVersion**: 3.0

#### Supported Video Formats:
- MP4, MOV, MKV, AVI, FLV

#### Example Usage:

1. Drag and drop a supported video file onto the action.
2. Enter the start and end times when prompted.
3. The video will be trimmed in place, creating a new file with "_trimmed" appended to the original filename.
4. If the file type is unsupported, an error message will be displayed.

## Installation

To install these actions, follow these steps:

1. Clone or download this repository.
2. Open Dropzone 4 and add a new action.
3. Select the corresponding `.dzaction` file for the desired action.
4. Configure if necessary and start using the action!

## Author
- **Name**: Dallas Crilley
- **Website**: [dallascrilley.com](https://dallascrilley.com)

## License

This project is licensed under the MIT License.
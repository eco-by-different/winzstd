![Repo size](https://img.shields.io/github/repo-size/eco-by-different/winzstd)
![Last commit](https://img.shields.io/github/last-commit/eco-by-different/winzstd)

# WinZSTD

WinZSTD 1.1.0 is a lightweight native Windows GUI for creating `.tar` and `.tar.zst` archives using the built-in Windows `tar.exe`.

No external binaries.  
No bundled tools.  
No 7-Zip dependency.  
Just Windows PowerShell, WinForms and Windows TAR.

## Philosophy

**eco-by-different**

Maximize efficiency.  
Minimize waste.  
Keep it practical.

WinZSTD follows the eco-by-different philosophy: use native Windows components, avoid unnecessary external dependencies, and keep everyday workflows simple.

## Features

- Native Windows PowerShell / WinForms GUI
- Uses built-in Windows `tar.exe`
- Creates `.tar` archives
- Creates `.tar.zst` archives
- Compression level timeline from `0` to `22`
- Default compression level: `11`
- Level `0` creates a plain `.tar` archive
- Levels `1-22` create `.tar.zst` archives
- Optional `Create .tar before ZSTD` mode
- `.tar` container is automatically enforced for folders
- `.tar` container is automatically enforced for level `0`
- Hidden background execution
- Simple status messages
- Optional output folder opening after successful archive creation
- No external compression binaries required

## Compression Timeline

WinZSTD 1.1.0 replaces the old fixed `STORE / NORMAL / EXTREME` buttons with a simple compression timeline.

The compression timeline is intentionally adjustable because the highest ZSTD level is not always the best practical choice for every file type. Higher levels can improve compression ratio, but they can also be slower and may require more system resources. In many real-world cases, a level such as `19` can be a better practical choice than `22`.

- `0` = STORE / `.tar`
- `1` = fastest ZSTD compression
- `11` = default balanced level
- `19` = strong practical compression
- `22` = maximum ZSTD level

### Level 0

Creates a plain `.tar` archive without Zstandard compression.

Output example:

- `output.tar`

### Levels 1-22

Creates a `.tar.zst` archive using Zstandard compression through Windows `tar.exe`.

Output example:

- `output.tar.zst`

### Default level

The default compression level is `11`.

This is intended as a practical middle-ground between compression speed and output size.

### High compression levels

Higher levels such as `18-22` may produce smaller archives, but compression can be slower and may require more system resources.

Level `22` is the maximum ZSTD level, but it is not always the best practical choice. Depending on the input data, level `19` can often provide a better balance between compression ratio, time and resource usage.

## TAR before ZSTD

WinZSTD includes a `Create .tar before ZSTD` option.

This keeps archive structure clear and consistent:

- `file.iso` -> `file.iso.tar.zst`
- `folder` -> `folder.tar.zst`

For folders, the TAR container is automatically required because Zstandard itself is a stream compressor, while TAR provides the archive container for files and directories.

## Why Windows tar.exe?

WinZSTD intentionally uses the native Windows `tar.exe` backend.

This keeps the project simple:

- no external compression binaries
- no bundled tools
- no 7-Zip dependency
- no installer required
- portable EXE release
- native Windows archive creation

## Recommended use

Use level `0` when you only need a plain `.tar` archive.

Use level `11` for balanced `.tar.zst` compression.

Use levels around `18-19` when you want strong compression with a practical balance between output size and compression time.

Use level `22` only when maximum compression level is desired and compression speed is not important.

## Screenshot

![WinZSTD screenshot](assets/WinZSTD-screenshot.png)

## Download

Latest release:  
https://github.com/eco-by-different/winzstd/releases/latest

Direct download:  
https://github.com/eco-by-different/winzstd/releases/latest/download/WinZSTD.exe

## Source code

The PowerShell source is available in this repository:

- `WinZSTD.ps1`

## Requirements

- Windows 10 / Windows 11
- Built-in Windows `tar.exe`
- Windows PowerShell
- WinForms

No external archiver or compressor is required.

## Version history

### WinZSTD 1.1.0

- Added compression level timeline from `0` to `22`
- Added default compression level `11`
- Added optional `Create .tar before ZSTD` mode
- Level `0` creates `.tar`
- Levels `1-22` create `.tar.zst`
- Folder input automatically enforces TAR container
- Improved GUI layout
- Minor compact code cleanup

### WinZSTD 1.0.0

- Initial public release
- Added basic `STORE`, `NORMAL`, and `EXTREME` archive profiles
- Added native Windows TAR/ZSTD GUI powered by Windows `tar.exe`

## License

MIT License

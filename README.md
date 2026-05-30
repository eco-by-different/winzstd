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
- Optional `.tar` container before ZSTD compression
- `.tar` container is automatically enforced for folders
- Hidden background execution
- Simple status messages
- Optional output folder opening after successful archive creation
- No external compression binaries required

## Compression Timeline

WinZSTD 1.1.0 replaces the old fixed `STORE / NORMAL / EXTREME` buttons with a simple compression timeline.

### Level 0

Creates a plain `.tar` archive without Zstandard compression.

```text
output.tar

![Repo size](https://img.shields.io/github/repo-size/eco-by-different/winzstd)
![Last commit](https://img.shields.io/github/last-commit/eco-by-different/winzstd)

# WinZSTD

**WinZSTD 1.2** is a lightweight native Windows GUI for creating `.tar`, `.tar.zst` and `.zst` archives using the built-in Windows `tar.exe`.

No external binaries.  
No bundled tools.  
No 7-Zip dependency.  
Just Windows PowerShell, WinForms and Windows TAR.

---

## Philosophy

**eco-by-different**

Maximize efficiency.  
Minimize waste.  
Keep it practical.

WinZSTD follows the eco-by-different philosophy:

- use native Windows components
- avoid unnecessary external dependencies
- keep everyday workflows simple
- provide a clean GUI layer over native Windows TAR/ZSTD functionality

---

## What Is WinZSTD?

WinZSTD is not a full archive manager.

It is a small and practical GUI layer over Windows `tar.exe`, designed for one clear purpose:

> Create `.tar`, `.tar.zst` and `.zst` files quickly and comfortably using native Windows tools.

Windows already includes `tar.exe`, but creating TAR/ZSTD archives from a simple dedicated GUI is not always convenient. WinZSTD fills that gap.

---

## Features

- Native Windows PowerShell / WinForms GUI
- Uses built-in Windows `tar.exe`
- Creates `.tar` archives
- Creates `.tar.zst` archives
- Creates direct `.zst` files for single-file compression
- Compression level timeline from `0` to `22`
- Default compression level: `11`
- Level `0` creates a plain `.tar` archive
- Levels `1–22` create ZSTD-compressed archives
- Optional `Create .tar before ZSTD` mode
- TAR container is automatically enforced for folders
- TAR container is automatically enforced for level `0`
- Bottom progress bar during archive creation
- Hidden background execution
- Simple status messages
- Optional output folder opening after successful archive creation
- No external compression binaries required

---

## Compression Timeline

WinZSTD uses a simple adjustable compression timeline:

```text
0 STORE ................................ 22 EXTREME
```

The compression timeline is intentionally adjustable because the highest ZSTD level is not always the best practical choice for every file type.

Higher levels can improve compression ratio, but they can also be slower and may require more system resources.

In many real-world cases, a level such as `19` can be a better practical choice than `22`.

Recommended reference points:

```text
0  = STORE / .tar
1  = fastest ZSTD compression
11 = default balanced level
19 = strong practical compression
22 = maximum ZSTD level
```

---

## Compression Modes

### Level 0 — STORE

Creates a plain `.tar` archive without Zstandard compression.

Output example:

```text
output.tar
```

Use this mode when you only need a standard TAR archive without compression.

---

### Levels 1–22 — TAR.ZST

Creates a `.tar.zst` archive using Zstandard compression through Windows `tar.exe`.

Output example:

```text
output.tar.zst
```

This is the recommended mode for folders and for standard archive workflows.

---

### Levels 1–22 — Direct ZST

For single files, WinZSTD can create a direct `.zst` file when `Create .tar before ZSTD` is disabled.

Output example:

```text
output.zst
```

This is useful when you want to compress one file directly without wrapping it into a TAR container first.

---

## File vs Folder Behavior

### Folder Input

Folders are always packed through TAR first.

Possible outputs:

```text
folder.tar
folder.tar.zst
```

This behavior is intentional because Zstandard itself is a stream compressor, while TAR provides the archive container for files and directories.

---

### File Input

Files can be compressed either through TAR/ZSTD:

```text
file.tar.zst
```

or directly as ZSTD:

```text
file.zst
```

depending on the `Create .tar before ZSTD` option.

---

## How It Works

WinZSTD uses Windows `tar.exe` in the background.

Basic archive creation is based on:

```powershell
tar.exe -cf output.tar -C parent-folder input-name
```

For ZSTD compression, WinZSTD uses Windows TAR/libarchive options:

```powershell
--options zstd:compression-level=LEVEL
```

Example:

```powershell
tar.exe -a --options zstd:compression-level=19 -cf output.tar.zst -C parent-folder input-folder
```

WinZSTD runs the archive operation in a hidden background PowerShell worker and shows a bottom progress bar while the operation is running.

---

## Why Windows tar.exe?

WinZSTD intentionally uses the native Windows `tar.exe` backend.

This keeps the project simple:

- no external compression binaries
- no bundled tools
- no 7-Zip dependency
- no installer required
- portable EXE release possible
- native Windows archive creation

---

## Recommended Use

Use level `0` when you only need a plain `.tar` archive.

Use level `11` for balanced `.tar.zst` compression.

Use levels around `18–19` when you want strong compression with a practical balance between output size and compression time.

Use level `22` only when maximum compression level is desired and compression speed is not important.

---

## Requirements

- Windows 10 or Windows 11
- Built-in Windows `tar.exe`
- Windows PowerShell 5.1
- .NET / WinForms support available in Windows

No external archiver or compressor is required.

You do not need to install:

- Zstandard CLI
- 7-Zip
- PeaZip
- WinRAR
- any additional compression backend

---

## Usage

1. Run `WinZSTD.ps1` or the compiled `WinZSTD.exe`
2. Select a file or folder
3. Choose the destination archive path
4. Select compression level using the slider
5. Optionally enable or disable `Create .tar before ZSTD`
6. Click `CREATE ARCHIVE`
7. Wait until the operation finishes
8. Optionally open the output folder after successful creation

---

## Download

Latest release:

```text
https://github.com/eco-by-different/winzstd/releases/latest
```

Direct EXE download:

```text
https://github.com/eco-by-different/winzstd/releases/latest/download/WinZSTD.exe
```

Source code:

```text
WinZSTD.ps1
```

---

## Screenshot

Add screenshot here:

```markdown
![WinZSTD screenshot](screenshots/winzstd-1.2.png)
```

Recommended repository path:

```text
screenshots/winzstd-1.2.png
```

---

## Build EXE

WinZSTD can be packaged as an `.exe` using PS2EXE.

Example build command:

```powershell
Invoke-ps2exe `
  -inputFile ".\WinZSTD.ps1" `
  -outputFile ".\WinZSTD.exe" `
  -noConsole `
  -title "WinZSTD 1.2" `
  -description "Native Windows TAR/ZSTD GUI powered by Windows tar.exe" `
  -company "eco-by-different" `
  -product "WinZSTD" `
  -version "1.2.0.0"
```

Recommended GitHub release tag:

```text
v1.2.0
```

Recommended EXE version:

```text
1.2.0.0
```

Important note:

```text
GitHub tag can be v1.2.0
EXE version must be numeric only: 1.2.0.0
```

---

## Portable Usage

WinZSTD is designed to be simple and portable.

You can use either:

```text
WinZSTD.ps1
```

or the compiled:

```text
WinZSTD.exe
```

No installer is required.

---

## Security Note

WinZSTD does not bundle external binaries.

The application uses:

- Windows PowerShell
- Windows WinForms
- Windows built-in `tar.exe`

Temporary worker/config files are created in the user temp directory during archive creation and removed after the operation finishes.

---

## What WinZSTD Is Not

WinZSTD intentionally stays minimal.

It is not intended to replace full archive managers such as 7-Zip, PeaZip, WinRAR or similar tools.

WinZSTD does not currently provide:

- archive browsing
- archive editing
- password protection
- multi-format archive management
- advanced ZSTD dictionary features
- batch queue processing
- built-in archive extraction UI

This is intentional.

WinZSTD is focused on one job:

```text
Create TAR/ZSTD archives quickly using native Windows tools.
```

---

## Suggested Repository Structure

```text
winzstd/
├─ WinZSTD.ps1
├─ WinZSTD.exe
├─ README.md
├─ LICENSE
└─ screenshots/
   └─ winzstd-1.2.png
```

---

## Version History

### WinZSTD 1.2.0

Added:

- Bottom progress bar during archive creation
- Cleaner compact code formatting
- Improved visual feedback while archive creation is running

Improved:

- More comfortable archive creation workflow
- Better user feedback during processing
- Cleaner script structure while keeping the same minimal approach

Kept:

- Native Windows `tar.exe` backend
- No external binaries
- No 7-Zip dependency
- Minimal WinForms interface
- Compression level workflow from `0` to `22`

---

### WinZSTD 1.1.0

Added:

- Compression level timeline from `0` to `22`
- Default compression level `11`
- Optional `Create .tar before ZSTD` mode
- Level `0` creates `.tar`
- Levels `1–22` create `.tar.zst`
- Folder input automatically enforces TAR container
- Improved GUI layout
- Minor compact code cleanup

---

### WinZSTD 1.0.0

Initial public release.

Added:

- Basic `STORE`, `NORMAL` and `EXTREME` archive profiles
- Native Windows TAR/ZSTD GUI powered by Windows `tar.exe`
- No external compression binaries required

---

## License

MIT License

---

## Author

Created by **eco-by-different**  
with practical AI-assisted development support.

---

## Summary

WinZSTD is a compact native Windows TAR/ZSTD GUI.

It keeps the workflow simple:

```text
Select input → choose compression level → create archive
```

No external binaries.  
No bundled tools.  
No unnecessary complexity.

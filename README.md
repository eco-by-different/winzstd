![Repo size](https://img.shields.io/github/repo-size/eco-by-different/winzstd)
![Last commit](https://img.shields.io/github/last-commit/eco-by-different/winzstd)

# WinZSTD

**WinZSTD 1.0** is a lightweight native Windows GUI for creating `.tar` and `.tar.zst` archives using the built-in Windows `tar.exe`.

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
- STORE profile: `.tar`
- NORMAL profile: `.tar.zst`
- EXTREME profile: `.tar.zst` with Zstandard level 22
- Hidden background execution
- Simple status messages
- Optional output folder opening after successful archive creation
- No external compression binaries required

## Compression Profiles

### STORE

Creates a plain `.tar` archive without Zstandard compression.

### NORMAL

Creates a `.tar.zst` archive using the default Windows/libarchive Zstandard behavior.

### EXTREME

Creates a `.tar.zst` archive using:

```powershell
--options zstd:compression-level=22
```

## Download

Latest release:  
https://github.com/eco-by-different/winzstd/releases/latest

Direct download:  
https://github.com/eco-by-different/winzstd/releases/download/v1.0.0/WinZSTD_1.0.0.zip

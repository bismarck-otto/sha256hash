# bismarck-otto 2025-08-08 to calculate hash with MD5-Hash.ps1

# Copyright (c) 2025 Otto von Bismarck
# This project includes portions generated using OpenAI’s ChatGPT.
# All code is released under the MIT License.

# Code snippets for file hash calculation
# ================================================================
#
# Create a shortcut in the SendTo folder:
# a) Press Win + R, type shell:sendto, press Enter.
# b) Right-click in the folder → New > Shortcut.
# c) Point it to/Type the location to the item:
#    powershell.exe -ExecutionPolicy Bypass -File "C:\Path\To\MD5-Hash.ps1"
# d) Replace C:\Path\To\ with the actual path to your MD5-Hash.ps1 file.
# e) Name it something like MD5 Hash.
# f) Right-click on the new shortcut → Properties > Run: 'Mimimized'.

# MD5-Hash.ps1
param (
    [string]$FilePath = $args[0]
)

if (!(Test-Path -LiteralPath $FilePath)) {
    [System.Windows.Forms.MessageBox]::Show("File not found: $FilePath", "Error", 0)
    exit 1
}

Add-Type -AssemblyName System.Windows.Forms

$hash = Get-FileHash -Algorithm MD5 -Path $FilePath
$fileName = [System.IO.Path]::GetFileName($FilePath)

# Lowercase hash for clipboard
$lowerHash = $hash.Hash.ToLower()
[System.Windows.Forms.Clipboard]::SetText("md5:$lowerHash")

# Lowercase + space every 2 hex chars + new line for messagebox
# Add space every 2 hex chars for messagebox
$spacedHash = ($lowerHash -replace '(.{2})', '$1 ').Trim()

# Output to messagebox
[System.Windows.Forms.MessageBox]::Show(
    "MD5 hash of $fileName`n`n$spacedHash",
    "MD5 Hash", 0
)

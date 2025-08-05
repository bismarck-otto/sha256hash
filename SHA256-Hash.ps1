# bismarck-otto 2025-08-05 to calculate hash with SHA256-Hash.ps1

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
#    powershell.exe -ExecutionPolicy Bypass -File "C:\Path\To\SHA256-Hash.ps1"
# d) Replace C:\Path\To\ with the actual path to your SHA256-Hash.ps1 file.
# e) Name it something like SHA256 Hash.
# f) Right-click on the new shortcut → Properties > Run: 'Mimimized'.

# SHA256-Hash.ps1
param (
    [string]$FilePath = $args[0]
)

if (!(Test-Path -LiteralPath $FilePath)) {
    [System.Windows.Forms.MessageBox]::Show("File not found: $FilePath", "Error", 0)
    exit 1
}

Add-Type -AssemblyName System.Windows.Forms

$hash = Get-FileHash -Algorithm SHA256 -Path $FilePath
$fileName = [System.IO.Path]::GetFileName($FilePath)

[System.Windows.Forms.Clipboard]::SetText($hash.Hash)
[System.Windows.Forms.MessageBox]::Show("SHA-256 Hash for the file '$fileName' is listed below and copied to the clipboard:`n`n$($hash.Hash)", "SHA-256 Hash", 0)

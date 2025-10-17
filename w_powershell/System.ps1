# System utilities PowerShell functions for dev_scripts
# System utilities like ds:recent, ds:sedi, ds:diff, ds:dups, etc.

# Import core and utility functions
. "$PSScriptRoot\Core.ps1"
. "$PSScriptRoot\Utils.ps1"

function ds:recent {
    <#
    .SYNOPSIS
    List files modified recently
    
    .DESCRIPTION
    Lists files that have been modified within the specified number of days.
    Equivalent to bash ds:recent function.
    
    .PARAMETER Directory
    Directory to search (default: current directory)
    
    .PARAMETER Days
    Number of days to look back (default: 7)
    
    .PARAMETER Recurse
    Search recursively through subdirectories
    
    .PARAMETER Hidden
    Include hidden files
    
    .PARAMETER OnlyFiles
    Show only files, not directories
    
    .EXAMPLE
    ds:recent
    Shows files modified in the last 7 days in current directory
    
    .EXAMPLE
    ds:recent "C:\Projects" 3 -Recurse
    Shows files modified in the last 3 days recursively in C:\Projects
    #>
    param(
        [string]$Directory = ".",
        [int]$Days = 7,
        [switch]$Recurse,
        [switch]$Hidden,
        [switch]$OnlyFiles
    )
    
    if ($Directory -ne ".") {
        if (!(Test-Path $Directory -PathType Container)) {
            Write-Error "Unable to verify directory provided!"
            return 1
        }
    }
    
    $notFound = if ($Hidden) {
        "No files found modified in the last $Days days!"
    } else {
        "No non-hidden files found modified in the last $Days days!"
    }
    
    try {
        $files = @()
        
        if ($Recurse -or $OnlyFiles) {
            $searchPath = if ($Directory -eq ".") { Get-Location } else { $Directory }
            
            if ($OnlyFiles) {
                $files = Get-ChildItem -Path $searchPath -File -Recurse:$Recurse -Force:$Hidden |
                         Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-$Days) } |
                         Sort-Object LastWriteTime -Descending
            } else {
                $files = Get-ChildItem -Path $searchPath -Recurse:$Recurse -Force:$Hidden |
                         Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-$Days) } |
                         Sort-Object LastWriteTime -Descending
            }
        } else {
            $searchPath = if ($Directory -eq ".") { Get-Location } else { $Directory }
            $files = Get-ChildItem -Path $searchPath -Force:$Hidden |
                     Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-$Days) } |
                     Sort-Object LastWriteTime -Descending
        }
        
        if ($files.Count -eq 0) {
            Write-Host $notFound
            return 1
        }
        
        # Format output similar to bash version
        foreach ($file in $files) {
            $lastWrite = $file.LastWriteTime.ToString("MM/dd/yy HH:mm")
            $size = if ($file.PSIsContainer) { "<DIR>" } else { $file.Length }
            $name = $file.Name
            
            Write-Host ("{0,-12} {1,8} {2}" -f $lastWrite, $size, $name)
        }
        
        return 0
    } catch {
        Write-Error "Error searching for recent files: $_"
        return 1
    }
}

function ds:sedi {
    <#
    .SYNOPSIS
    Run global in place substitutions
    
    .DESCRIPTION
    Performs global search and replace operations on files or directories.
    Equivalent to bash ds:sedi function.
    
    .PARAMETER FileOrDir
    File or directory to process
    
    .PARAMETER Search
    Search pattern
    
    .PARAMETER Replace
    Replacement text
    
    .EXAMPLE
    ds:sedi "file.txt" "old" "new"
    Replace "old" with "new" in file.txt
    
    .EXAMPLE
    ds:sedi "." "TODO" "FIXME" -Confirm
    Replace "TODO" with "FIXME" in all files in current directory
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FileOrDir,
        
        [Parameter(Mandatory=$true)]
        [string]$Search,
        
        [string]$Replace = "",
        
        [switch]$Confirm
    )
    
    if (Test-Path $FileOrDir -PathType Leaf) {
        # Single file
        $file = $FileOrDir
        try {
            $content = Get-Content $file -Raw
            $newContent = $content -replace [regex]::Escape($Search), $Replace
            Set-Content $file $newContent -NoNewline
            Write-Host "Replaced `"$Search`" with `"$Replace`" in $file"
        } catch {
            Write-Error "Failed to process file $file : $_"
        }
    } else {
        # Directory or current directory
        $dir = if (Test-Path $FileOrDir -PathType Container) { $FileOrDir } else { "." }
        
        if ($Confirm) {
            $conf = Read-Host "Confirm replacement of `"$Search`" -> `"$Replace`" on all files in $dir (y/n)"
            if ($conf -ne "y") {
                Write-Host "No change made!"
                return
            }
        }
        
        try {
            $files = Get-ChildItem -Path $dir -Recurse -File | Where-Object {
                try {
                    $content = Get-Content $_.FullName -Raw -ErrorAction Stop
                    $content -match [regex]::Escape($Search)
                } catch {
                    $false
                }
            }
            
            foreach ($file in $files) {
                try {
                    $content = Get-Content $file.FullName -Raw
                    $newContent = $content -replace [regex]::Escape($Search), $Replace
                    Set-Content $file.FullName $newContent -NoNewline
                    Write-Host "Replaced `"$Search`" with `"$Replace`" in $($file.FullName)"
                } catch {
                    Write-Warning "Failed to process file $($file.FullName): $_"
                }
            }
        } catch {
            Write-Error "Failed to process directory $dir : $_"
        }
    }
}

function ds:diff {
    <#
    .SYNOPSIS
    Diff shortcut for an easier to read view
    
    .DESCRIPTION
    Provides a side-by-side diff view with better formatting.
    Equivalent to bash ds:diff function.
    
    .PARAMETER File1OrStr1
    First file or string to compare
    
    .PARAMETER File2OrStr2
    Second file or string to compare
    
    .PARAMETER SuppressCommon
    Suppress common lines
    
    .PARAMETER Color
    Enable color output
    
    .EXAMPLE
    ds:diff "file1.txt" "file2.txt"
    Compare two files
    
    .EXAMPLE
    ds:diff "hello" "world"
    Compare two strings
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$File1OrStr1,
        
        [Parameter(Mandatory=$true)]
        [string]$File2OrStr2,
        
        [switch]$SuppressCommon,
        
        [switch]$Color
    )
    
    $file1 = $null
    $file2 = $null
    $temp1 = $null
    $temp2 = $null
    
    try {
        # Handle first input
        if (Test-Path $File1OrStr1 -PathType Leaf) {
            $file1 = $File1OrStr1
        } else {
            $temp1 = ds:tmp "ds_diff1"
            Set-Content $temp1 $File1OrStr1 -NoNewline
            $file1 = $temp1
        }
        
        # Handle second input
        if (Test-Path $File2OrStr2 -PathType Leaf) {
            $file2 = $File2OrStr2
        } else {
            $temp2 = ds:tmp "ds_diff2"
            Set-Content $temp2 $File2OrStr2 -NoNewline
            $file2 = $temp2
        }
        
        # Use PowerShell's Compare-Object for diff functionality
        $content1 = Get-Content $file1
        $content2 = Get-Content $file2
        
        $maxLines = [Math]::Max($content1.Count, $content2.Count)
        
        for ($i = 0; $i -lt $maxLines; $i++) {
            $line1 = if ($i -lt $content1.Count) { $content1[$i] } else { "" }
            $line2 = if ($i -lt $content2.Count) { $content2[$i] } else { "" }
            
            if ($line1 -eq $line2) {
                if (!$SuppressCommon) {
                    Write-Host ("{0,-50} | {1}" -f $line1, $line2)
                }
            } else {
                if ($Color) {
                    Write-Host ("{0,-50} | {1}" -f $line1, $line2) -ForegroundColor Red
                } else {
                    Write-Host ("{0,-50} | {1}" -f $line1, $line2)
                }
            }
        }
    } finally {
        # Clean up temporary files
        if ($temp1) { Remove-Item $temp1 -ErrorAction SilentlyContinue }
        if ($temp2) { Remove-Item $temp2 -ErrorAction SilentlyContinue }
    }
}

function ds:dups {
    <#
    .SYNOPSIS
    Report duplicate files with option for deletion
    
    .DESCRIPTION
    Finds and reports duplicate files based on MD5 hash.
    Equivalent to bash ds:dups function.
    
    .PARAMETER Directory
    Directory to search (default: current directory)
    
    .PARAMETER Confirm
    Confirm deletion of duplicates
    
    .PARAMETER OutputFile
    Output file for results
    
    .PARAMETER TryNonMatchExt
    Try files with different extensions
    
    .EXAMPLE
    ds:dups
    Find duplicates in current directory
    
    .EXAMPLE
    ds:dups "C:\Projects" -Confirm
    Find and delete duplicates in C:\Projects
    #>
    param(
        [string]$Directory = ".",
        [switch]$Confirm,
        [string]$OutputFile = "",
        [switch]$TryNonMatchExt
    )
    
    if (!(Get-Command Get-FileHash -ErrorAction SilentlyContinue)) {
        Write-Error "Get-FileHash cmdlet not available - this command requires PowerShell 4.0 or later"
        return 1
    }
    
    try {
        $files = Get-ChildItem -Path $Directory -Recurse -File
        $hashes = @{}
        $duplicates = @()
        
        Write-Host "Calculating file hashes..."
        foreach ($file in $files) {
            try {
                $hash = (Get-FileHash $file.FullName -Algorithm MD5).Hash
                if ($hashes.ContainsKey($hash)) {
                    $duplicates += @{
                        Hash = $hash
                        Original = $hashes[$hash]
                        Duplicate = $file.FullName
                    }
                } else {
                    $hashes[$hash] = $file.FullName
                }
            } catch {
                Write-Warning "Failed to hash file $($file.FullName): $_"
            }
        }
        
        if ($duplicates.Count -eq 0) {
            Write-Host "No duplicate files found."
            return 0
        }
        
        Write-Host "Found $($duplicates.Count) duplicate files:"
        Write-Host ""
        
        foreach ($dup in $duplicates) {
            Write-Host "Hash: $($dup.Hash)"
            Write-Host "  Original: $($dup.Original)"
            Write-Host "  Duplicate: $($dup.Duplicate)"
            Write-Host ""
            
            if ($Confirm) {
                $conf = Read-Host "Delete duplicate file '$($dup.Duplicate)'? (y/n)"
                if ($conf -eq "y") {
                    try {
                        Remove-Item $dup.Duplicate -Force
                        Write-Host "Deleted: $($dup.Duplicate)"
                    } catch {
                        Write-Warning "Failed to delete $($dup.Duplicate): $_"
                    }
                }
            }
        }
        
        if ($OutputFile) {
            $duplicates | ConvertTo-Json | Set-Content $OutputFile
            Write-Host "Results saved to: $OutputFile"
        }
        
        return 0
    } catch {
        Write-Error "Error finding duplicates: $_"
        return 1
    }
}

function ds:todo {
    <#
    .SYNOPSIS
    List todo items found in paths
    
    .DESCRIPTION
    Searches for TODO, FIXME, and XXX comments in files.
    Equivalent to bash ds:todo function.
    
    .PARAMETER SearchPaths
    Paths to search (default: current directory)
    
    .EXAMPLE
    ds:todo
    Find todos in current directory
    
    .EXAMPLE
    ds:todo "C:\Projects", "C:\Code"
    Find todos in specified directories
    #>
    param(
        [string[]]$SearchPaths = @(".")
    )
    
    $patterns = @("TODO", "FIXME", "XXX")
    $regex = "($($patterns -join '|'))( |:|\-)"
    
    foreach ($path in $SearchPaths) {
        if (!(Test-Path $path)) {
            Write-Warning "$path is not a file or directory or is not found"
            continue
        }
        
        try {
            if (Test-Path $path -PathType Leaf) {
                # Single file
                $content = Get-Content $path -Raw
                $regexMatches = [regex]::Matches($content, $regex)
                foreach ($match in $regexMatches) {
                    Write-Host "$path : $($match.Value)"
                }
            } else {
                # Directory
                $files = Get-ChildItem -Path $path -Recurse -File | Where-Object {
                    $_.Extension -match '\.(txt|md|py|js|ts|cs|java|cpp|c|h|ps1|sh|bat)$'
                }
                
                foreach ($file in $files) {
                    try {
                        $content = Get-Content $file.FullName -Raw -ErrorAction Stop
                        $regexMatches = [regex]::Matches($content, $regex)
                        foreach ($match in $regexMatches) {
                            Write-Host "$($file.FullName) : $($match.Value)"
                        }
                    } catch {
                        # Skip files that can't be read
                        continue
                    }
                }
            }
        } catch {
            Write-Warning "Error processing $path : $_"
        }
        
        Write-Host ""
    }
}

function ds:unicode {
    <#
    .SYNOPSIS
    Get UTF-8 unicode for a character sequence
    
    .DESCRIPTION
    Converts characters to their Unicode code points.
    Equivalent to bash ds:unicode function.
    
    .PARAMETER String
    String to convert
    
    .PARAMETER OutputFormat
    Output format: codepoint, hex, or octet
    
    .EXAMPLE
    ds:unicode "Hello"
    Get Unicode code points for "Hello"
    
    .EXAMPLE
    "Hello" | ds:unicode
    Get Unicode code points from pipeline
    #>
    param(
        [string]$String = "",
        [ValidateSet("codepoint", "hex", "octet")]
        [string]$OutputFormat = "codepoint"
    )
    
    $inputData = if ($String) { $String } else { $input }
    
    if (!$inputData) {
        Write-Error "No input provided"
        return
    }
    
    foreach ($char in $inputData.ToCharArray()) {
        $codePoint = [int]$char
        
        switch ($OutputFormat) {
            "hex" {
                Write-Host ("%{0:X4}" -f $codePoint) -NoNewline
            }
            "octet" {
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($char)
                foreach ($byte in $bytes) {
                    Write-Host ("%{0:X2}" -f $byte) -NoNewline
                }
            }
            default {
                Write-Host ("\U{0:X4}" -f $codePoint) -NoNewline
            }
        }
    }
    Write-Host ""
}

function ds:color {
    <#
    .SYNOPSIS
    Get RGB from hex or hex from RGB
    
    .DESCRIPTION
    Converts between hex color codes and RGB values.
    Equivalent to bash ds:color function.
    
    .PARAMETER ColorValue
    Hex color (#RRGGBB) or RGB values
    
    .PARAMETER Green
    Green component (if providing RGB)
    
    .PARAMETER Blue
    Blue component (if providing RGB)
    
    .EXAMPLE
    ds:color "#FF0000"
    Convert hex to RGB
    
    .EXAMPLE
    ds:color 255 0 0
    Convert RGB to hex
    #>
    param(
        [string]$ColorValue = "",
        [int]$Green = 0,
        [int]$Blue = 0
    )
    
    $inputData = if ($ColorValue) { $ColorValue } else { $input }
    
    if (!$inputData) {
        Write-Error "Expected hex or rgb values."
        return
    }
    
    # Check if input is hex
    if ($inputData -match "^#?[0-9A-Fa-f]{6}$") {
        $hex = $inputData -replace "^#", ""
        $r = [Convert]::ToInt32($hex.Substring(0,2), 16)
        $g = [Convert]::ToInt32($hex.Substring(2,2), 16)
        $b = [Convert]::ToInt32($hex.Substring(4,2), 16)
        Write-Host "rgb($r, $g, $b)"
    }
    # Check if input is RGB format
    elseif ($input -match "^rgb\((\d+),\s*(\d+),\s*(\d+)\)$") {
        $matches = [regex]::Matches($input, "^rgb\((\d+),\s*(\d+),\s*(\d+)\)$")
        $r = [int]$matches.Groups[1].Value
        $g = [int]$matches.Groups[2].Value
        $b = [int]$matches.Groups[3].Value
        $hex = "#{0:X2}{1:X2}{2:X2}" -f $r, $g, $b
        Write-Host $hex
    }
    # Check if individual RGB values provided
    elseif ($ColorValue -match "^\d+$" -and $Green -match "^\d+$" -and $Blue -match "^\d+$") {
        $r = [int]$ColorValue
        $g = [int]$Green
        $b = [int]$Blue
        $hex = "#{0:X2}{1:X2}{2:X2}" -f $r, $g, $b
        Write-Host $hex
    }
    else {
        Write-Error "Malformed or missing hex or rgb values provided."
    }
}

function ds:random {
    <#
    .SYNOPSIS
    Generate a random number 0-1 or randomize text
    
    .DESCRIPTION
    Generates random numbers or randomizes text input.
    Equivalent to bash ds:random function.
    
    .PARAMETER Mode
    Mode: "number" for random number, "text" for text randomization
    
    .EXAMPLE
    ds:random "number"
    Generate a random number between 0 and 1
    
    .EXAMPLE
    "Hello World" | ds:random "text"
    Randomize the order of characters
    #>
    param(
        [ValidateSet("number", "text")]
        [string]$Mode = "number"
    )
    
    $inputData = if ($input) { $input } else { "" }
    
    switch ($Mode) {
        "number" {
            $random = Get-Random -Minimum 0 -Maximum 1000
            Write-Host ($random / 1000.0)
        }
        "text" {
            if ($inputData) {
                $chars = $inputData.ToCharArray()
                $shuffled = $chars | Sort-Object { Get-Random }
                Write-Host ($shuffled -join "")
            } else {
                Write-Host ""
            }
        }
    }
}

# Export functions for use in other modules
Export-ModuleMember -Function ds:recent, ds:sedi, ds:diff, ds:dups, ds:todo, ds:unicode, ds:color, ds:random

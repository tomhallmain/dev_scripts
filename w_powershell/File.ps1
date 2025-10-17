# File operations PowerShell functions for dev_scripts
# File operations like ds:vi, ds:grepvi, ds:cd, ds:searchx, etc.

# Import core and utility functions
. "$PSScriptRoot\Core.ps1"
. "$PSScriptRoot\Utils.ps1"

function ds:vi {
    <#
    .SYNOPSIS
    Search for files and open in editor
    
    .DESCRIPTION
    Searches for files matching a pattern and opens them in the default editor.
    Equivalent to bash ds:vi function.
    
    .PARAMETER Search
    Search pattern for file names (default: ".")
    
    .PARAMETER Directory
    Directory to search in (default: current directory)
    
    .PARAMETER EditAllMatch
    Edit all matching files instead of selecting one
    
    .EXAMPLE
    ds:vi "*.py"
    Searches for Python files and opens them
    
    .EXAMPLE
    ds:vi "test" "C:\Projects" -EditAllMatch
    Searches for files containing "test" in C:\Projects and opens all matches
    #>
    param(
        [string]$Search = ".",
        [string]$Directory = ".",
        [switch]$EditAllMatch
    )
    
    # Find files matching the search pattern
    $files = @()
    try {
        ds:file_check $Directory
        $files = Get-ChildItem -Path $Directory -Recurse -File | 
                 Where-Object { $_.Name -like "*$Search*" } | 
                 Select-Object -First 100 | 
                 ForEach-Object { $_.FullName }
    } catch {
        ds:die "Unable to find a match with current args"
    }
    
    if ($files.Count -eq 0) {
        ds:die "Unable to find a match with current args"
    }
    
    if ($files.Count -gt 1 -and !$EditAllMatch) {
        Write-Host "Multiple matches found - select a file:"
        for ($i = 0; $i -lt $files.Count; $i++) {
            Write-Host "$($i + 1). $($files[$i])"
        }
        
        do {
            $choice = Read-Host "Enter a number from the set of files or a pattern"
            if ([string]::IsNullOrEmpty($choice)) {
                $choice = 1
                break
            }
            elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $files.Count) {
                $selectedFile = $files[[int]$choice - 1]
                break
            }
            else {
                $matchingFiles = $files | Where-Object { $_ -like "*$choice*" }
                if ($matchingFiles.Count -eq 1) {
                    $selectedFile = $matchingFiles[0]
                    break
                }
                elseif ($matchingFiles.Count -gt 1) {
                    Write-Host "Multiple files match '$choice'. Please be more specific."
                }
                else {
                    Write-Host "No files match '$choice'. Please try again."
                }
            }
        } while ($true)
        
        if ($selectedFile) {
            Start-Process notepad $selectedFile
        }
    }
    else {
        # Open all files or single file
        foreach ($file in $files) {
            Start-Process notepad $file
        }
    }
}

function ds:grepvi {
    <#
    .SYNOPSIS
    Grep and open editor on match
    
    .DESCRIPTION
    Searches for content in files and opens the editor at the matching line.
    Equivalent to bash ds:grepvi function.
    
    .PARAMETER Search
    Search pattern for content
    
    .PARAMETER FileOrDir
    File or directory to search in
    
    .PARAMETER EditAllMatch
    Edit all matching files instead of selecting one
    
    .EXAMPLE
    ds:grepvi "function" "*.ps1"
    Searches for "function" in PowerShell files and opens matches
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Search,
        
        [string]$FileOrDir = ".",
        [switch]$EditAllMatch
    )
    
    $fileMatches = @()
    
    if (Test-Path $FileOrDir -PathType Leaf) {
        # Single file
        $content = Get-Content $FileOrDir
        for ($i = 0; $i -lt $content.Length; $i++) {
            if ($content[$i] -match $Search) {
                $fileMatches += @{
                    File = $FileOrDir
                    Line = $i + 1
                    Content = $content[$i]
                }
            }
        }
    }
    else {
        # Directory search
        $files = Get-ChildItem -Path $FileOrDir -Recurse -File | Where-Object { $_.Extension -in @('.txt', '.ps1', '.py', '.js', '.html', '.css', '.json', '.xml', '.md') }
        
        foreach ($file in $files) {
            try {
                $content = Get-Content $file.FullName -ErrorAction SilentlyContinue
                for ($i = 0; $i -lt $content.Length; $i++) {
                    if ($content[$i] -match $Search) {
                        $fileMatches += @{
                            File = $file.FullName
                            Line = $i + 1
                            Content = $content[$i]
                        }
                    }
                }
            }
            catch {
                # Skip files that can't be read
                continue
            }
        }
    }
    
    if ($fileMatches.Count -eq 0) {
        ds:die "No matches found for '$Search'"
    }
    
    if ($fileMatches.Count -gt 1 -and !$EditAllMatch) {
        Write-Host "Multiple matches found - select a file:"
        $uniqueFiles = $fileMatches | Group-Object File | ForEach-Object { $_.Name }
        for ($i = 0; $i -lt $uniqueFiles.Count; $i++) {
            Write-Host "$($i + 1). $($uniqueFiles[$i])"
        }
        
        $choice = Read-Host "Enter a number from the set of files"
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $uniqueFiles.Count) {
            $selectedFile = $uniqueFiles[[int]$choice - 1]
            $selectedFileMatches = $fileMatches | Where-Object { $_.File -eq $selectedFile }
            $firstMatch = $selectedFileMatches[0]
            Start-Process notepad $firstMatch.File
        }
    }
    else {
        # Open first match
        $firstMatch = $fileMatches[0]
        Start-Process notepad $firstMatch.File
    }
}

function ds:cd {
    <#
    .SYNOPSIS
    Change to higher or lower level directories
    
    .DESCRIPTION
    Changes directory by searching for directories matching a pattern.
    Equivalent to bash ds:cd function.
    
    .PARAMETER Search
    Directory name or pattern to search for
    
    .EXAMPLE
    ds:cd "src"
    Changes to a directory named "src"
    
    .EXAMPLE
    ds:cd "project*"
    Changes to a directory matching "project*"
    #>
    param([string]$Search)
    
    if ([string]::IsNullOrEmpty($Search)) {
        Set-Location $env:HOME
        return
    }
    
    # Check if it's already a valid directory
    if (Test-Path $Search -PathType Container) {
        Set-Location $Search
        return
    }
    
    # Search for directories
    $dirs = @()
    
    # Search in current directory and parent directories
    $currentDir = Get-Location
    for ($i = 0; $i -lt 7; $i++) {
        $searchPath = if ($i -eq 0) { $currentDir } else { Join-Path $currentDir ("..\" * $i) }
        
        if (Test-Path $searchPath) {
            $foundDirs = Get-ChildItem -Path $searchPath -Directory | Where-Object { $_.Name -like "*$Search*" }
            if ($foundDirs) {
                $dirs += $foundDirs | ForEach-Object { $_.FullName }
            }
        }
    }
    
    if ($dirs.Count -eq 0) {
        ds:die "Unable to find a match with current args"
    }
    
    if ($dirs.Count -eq 1) {
        Set-Location $dirs[0]
    }
    else {
        Write-Host "Multiple matches found - select a directory:"
        for ($i = 0; $i -lt $dirs.Count; $i++) {
            Write-Host "$($i + 1). $($dirs[$i])"
        }
        
        $choice = Read-Host "Enter a number from the set of directories or a pattern"
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $dirs.Count) {
            Set-Location $dirs[[int]$choice - 1]
        }
        else {
            $matchingDirs = $dirs | Where-Object { $_ -like "*$choice*" }
            if ($matchingDirs.Count -eq 1) {
                Set-Location $matchingDirs[0]
            }
            else {
                Write-Warning "Unable to find a match with current args"
            }
        }
    }
}

function ds:searchx {
    <#
    .SYNOPSIS
    Search for code objects (functions, classes, etc.)
    
    .DESCRIPTION
    Searches for code objects like functions, classes, or other structured elements.
    Equivalent to bash ds:searchx function.
    
    .PARAMETER FileOrDir
    File or directory to search in
    
    .PARAMETER Search
    Search pattern for code objects
    
    .PARAMETER Quick
    Quick search mode
    
    .PARAMETER Multilevel
    Search in multiple levels
    
    .EXAMPLE
    ds:searchx "script.ps1" "function"
    Searches for functions in script.ps1
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FileOrDir,
        
        [string]$Search = "",
        [switch]$Quick,
        [switch]$Multilevel
    )
    
    try {
        ds:file_check $FileOrDir
    } catch {
        ds:die "File or directory '$FileOrDir' not found"
    }
    
    if (Test-Path $FileOrDir -PathType Container) {
        # Directory search
        $files = Get-ChildItem -Path $FileOrDir -Recurse -File | 
                 Where-Object { $_.Extension -in @('.ps1', '.py', '.js', '.cs', '.java', '.cpp', '.c', '.h') }
        
        foreach ($file in $files) {
            try {
                $content = Get-Content $file.FullName -ErrorAction SilentlyContinue
                $found = $false
                
                foreach ($line in $content) {
                    if ([string]::IsNullOrEmpty($Search) -or $line -match $Search) {
                        if ($line -match '\{|\}|function|class|def|public|private|protected') {
                            if (!$found) {
                                Write-Host "`n$($file.FullName)"
                                $found = $true
                            }
                            Write-Host "  $line"
                        }
                    }
                }
            }
            catch {
                continue
            }
        }
    }
    else {
        # Single file search
        if (Test-Path $FileOrDir) {
            $content = Get-Content $FileOrDir
            foreach ($line in $content) {
                if ([string]::IsNullOrEmpty($Search) -or $line -match $Search) {
                    if ($line -match '\{|\}|function|class|def|public|private|protected') {
                        Write-Host $line
                    }
                }
            }
        }
    }
}

function ds:select {
    <#
    .SYNOPSIS
    Select code by regex anchors
    
    .DESCRIPTION
    Selects lines between two regex patterns.
    Equivalent to bash ds:select function.
    
    .PARAMETER File
    File to select from (if not piped)
    
    .PARAMETER StartPattern
    Starting regex pattern
    
    .PARAMETER EndPattern
    Ending regex pattern
    
    .EXAMPLE
    ds:select "script.ps1" "function" "}"
    Selects lines between function and }
    #>
    param(
        [Parameter(ValueFromPipeline=$true)]
        [string]$File,
        
        [string]$StartPattern,
        [string]$EndPattern
    )
    
    if ($File -and (Test-Path $File)) {
        try {
            ds:file_check $File
            $content = Get-Content $File
            $inRange = $false
            
            foreach ($line in $content) {
                if ($line -match $StartPattern) {
                    $inRange = $true
                }
                
                if ($inRange) {
                    Write-Host $line
                }
                
                if ($inRange -and $line -match $EndPattern) {
                    break
                }
            }
        } catch {
            ds:die "Unable to process file '$File'"
        }
    }
}

function ds:insert {
    <#
    .SYNOPSIS
    Insert content into a file at specified location
    
    .DESCRIPTION
    Inserts content into a file at a specific line number or pattern.
    Equivalent to bash ds:insert function.
    
    .PARAMETER File
    Target file to insert into
    
    .PARAMETER Location
    Line number or pattern to insert at
    
    .PARAMETER Source
    Source content to insert
    
    .PARAMETER InPlace
    Modify file in place
    
    .EXAMPLE
    ds:insert "script.ps1" 10 "Write-Host 'Hello'"
    Inserts content at line 10
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$File,
        
        [Parameter(Mandatory=$true)]
        [string]$Location,
        
        [Parameter(Mandatory=$true)]
        [string]$Source,
        
        [switch]$InPlace
    )
    
    try {
        ds:file_check $File
    } catch {
        ds:die "File '$File' not found"
    }
    
    $content = Get-Content $File
    $newContent = @()
    
    if ($Location -match '^\d+$') {
        # Line number
        $lineNum = [int]$Location
        for ($i = 0; $i -lt $content.Length; $i++) {
            if ($i -eq $lineNum - 1) {
                $newContent += $Source
            }
            $newContent += $content[$i]
        }
    }
    else {
        # Pattern search
        $found = $false
        foreach ($line in $content) {
            if (!$found -and $line -match $Location) {
                $newContent += $Source
                $found = $true
            }
            $newContent += $line
        }
    }
    
    if ($InPlace) {
        $newContent | Set-Content $File
    }
    else {
        $newContent | Write-Output
    }
}

function ds:filename_str {
    <#
    .SYNOPSIS
    Add string to filename, preserving path
    
    .DESCRIPTION
    Modifies a filename by adding a string while preserving the path.
    Equivalent to bash ds:filename_str function.
    
    .PARAMETER FilePath
    Original file path
    
    .PARAMETER String
    String to add to filename
    
    .PARAMETER Position
    Where to add the string: prepend, append, or replace
    
    .PARAMETER AbsolutePath
    Return absolute path
    
    .EXAMPLE
    ds:filename_str "file.txt" "_backup" "append"
    Returns "file_backup.txt"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$true)]
        [string]$String,
        
        [ValidateSet("prepend", "append", "replace")]
        [string]$Position = "append",
        
        [switch]$AbsolutePath
    )
    
    $pathElements = ds:path_elements $FilePath
    
    if (!(Test-Path $pathElements.Directory)) {
        ds:die "Filepath given is invalid"
    }
    
    $newFilename = switch ($Position) {
        "prepend" { "$String$($pathElements.Filename)$($pathElements.Extension)" }
        "append" { "$($pathElements.Filename)$String$($pathElements.Extension)" }
        "replace" { "$String$($pathElements.Extension)" }
    }
    
    $result = Join-Path $pathElements.Directory $newFilename
    
    if ($AbsolutePath) {
        return (Resolve-Path $result).Path
    }
    else {
        return $newFilename
    }
}

# Export functions for use in other modules
Export-ModuleMember -Function ds:vi, ds:grepvi, ds:cd, ds:searchx, ds:select, ds:insert, ds:filename_str

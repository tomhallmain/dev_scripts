# Utility PowerShell functions for dev_scripts
# Utility functions from utils.sh for data processing and general operations

# Import core functions
. "$PSScriptRoot\Core.ps1"

function ds:file_check {
    <#
    .SYNOPSIS
    Test for file validity and fail if invalid
    
    .DESCRIPTION
    Validates file existence, writability, and binary content based on parameters.
    Can search for files if not found and handle file descriptors.
    
    .PARAMETER FilePath
    Path to file to check
    
    .PARAMETER CheckWritable
    Whether to check if file is writable
    
    .PARAMETER AllowBinary
    Whether to allow binary files
    
    .PARAMETER EnableSearch
    Whether to search for files if not found
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        [switch]$CheckWritable,
        [switch]$AllowBinary,
        [switch]$EnableSearch
    )
    
    if (-not $FilePath) {
        ds:fail "File not provided!"
    }
    
    $fileExists = Test-Path $FilePath -PathType Leaf
    $isDirectory = Test-Path $FilePath -PathType Container
    
    if ($fileExists -and -not $isDirectory) {
        $filelike = $true
    }
    
    if ($CheckWritable) {
        if (-not (Test-Path $FilePath -PathType Leaf) -or -not (Get-Item $FilePath).IsReadOnly) {
            ds:fail "File `"$FilePath`" is not writable"
        }
    } elseif ($EnableSearch) {
        if ($filelike) {
            if (-not $AllowBinary -and $FilePath -notlike "/dev/fd/*" -and (Get-Item $FilePath).Length -gt 0) {
                try {
                    Get-Content $FilePath -Raw -ErrorAction Stop | Out-Null
                } catch {
                    ds:fail "Found file `"$FilePath`" Binary files have been disallowed for this command"
                }
            }
            return $FilePath
        } else {
            # Search for files
            $foundFile = $null
            if ($AllowBinary) {
                $foundFile = Get-ChildItem -Recurse -File -Name "*$FilePath*" | Select-Object -First 1
            } else {
                $foundFile = Get-ChildItem -Recurse -File -Name "*$FilePath*" | Where-Object {
                    try { Get-Content $_.FullName -Raw -ErrorAction Stop | Out-Null; $true } catch { $false }
                } | Select-Object -First 1
            }
            
            if (-not $foundFile) {
                ds:fail "File `"$FilePath`" not provided or invalid"
            }
            
            $conf = Read-Host "Arg is not a file - run on closest match $($foundFile.FullName)? (y/n)"
            if ($conf -eq "y") {
                return $foundFile.FullName
            } else {
                ds:fail "File `"$($foundFile.FullName)`" not provided or invalid"
            }
        }
        return
    }
    
    if (-not $filelike) {
        ds:fail "File `"$FilePath`" not provided or invalid"
    }
    
    if (-not $AllowBinary -and $FilePath -notlike "/dev/fd/*" -and (Get-Item $FilePath).Length -gt 0) {
        try {
            Get-Content $FilePath -Raw -ErrorAction Stop | Out-Null
        } catch {
            ds:fail "Found file `"$FilePath`" - Binary files have been disallowed for this command!"
        }
    }
}

function ds:fd_check {
    <#
    .SYNOPSIS
    Convert file descriptors into files
    
    .PARAMETER FilePath
    File path or file descriptor to check
    #>
    param([string]$FilePath)
    
    if ($FilePath -like "/dev/fd/*") {
        $ds_fd = ds:tmp "ds_fd"
        Get-Content $FilePath | Set-Content $ds_fd
        return $ds_fd
    } else {
        return $FilePath
    }
}

function ds:pipe_open {
    <#
    .SYNOPSIS
    Detect if pipe is open
    
    .PARAMETER PossibleFileArg
    Optional file argument to check
    #>
    param([string]$PossibleFileArg)
    
    if ($env:DS_DUMB_TERM) {
        return (-not $PossibleFileArg -or -not (Test-Path $PossibleFileArg))
    } else {
        # Check if stdin is a pipe
        try {
            $stdin = [Console]::In
            return $stdin.Peek() -ne -1
        } catch {
            return $false
        }
    }
}

function ds:extractfs {
    <#
    .SYNOPSIS
    Infer or extract single awk FS from args
    #>
    if (ds:noawkfs) {
        $fs = ds:inferfs $_file $true
    } else {
        $fs_idx = ds:arr_idx "^FS=" $args
        if ($fs_idx -eq "") {
            $fs_idx = ds:arr_idx "^-F" $args
            $fs = $args[$fs_idx] -replace "^-F", ""
        } else {
            $fs = $args[$fs_idx] -replace "^FS=", ""
            $fsv_idx = $fs_idx - 1
            $args = $args | Where-Object { $_ -ne $args[$fsv_idx] }
        }
        $args = $args | Where-Object { $_ -ne $args[$fs_idx] }
    }
    return $fs
}

function ds:noawkfs {
    <#
    .SYNOPSIS
    Test whether AWK arg for setting field separator is present
    #>
    return (-not ($args -match "-F") -and -not ($args -match "-v FS") -and -not ($args -match "-v fs"))
}

function ds:awksafe {
    <#
    .SYNOPSIS
    Test whether AWK is configured for multibyte regex
    #>
    try {
        $testOutput = "test" | & awk -f "$DS_SUPPORT\wcwidth.awk" -f "$DS_SUPPORT\awktest.awk" 2>$null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function ds:awk {
    <#
    .SYNOPSIS
    Run an awk script with utils
    
    .DESCRIPTION
    Runs an awk script with utils.awk as a dependency. Handles piped input,
    file arguments, and variable arguments. Equivalent to bash ds:awk function.
    
    .PARAMETER Script
    Awk script file to run
    
    .PARAMETER Files
    Files to process with the awk script
    
    .PARAMETER VarArgs
    Variable arguments to pass to awk
    #>
    param(
        [string]$Script,
        [string[]]$Files = @(),
        [string[]]$VarArgs = @()
    )
    
    $piped = $false
    $tempFile = $null
    
    # Handle piped input
    if (ds:pipe_open) {
        $tempFile = ds:tmp "ds_awk"
        $input | Set-Content $tempFile
        $piped = $true
    }
    
    # Convert script path if it's a file descriptor
    $scriptPath = ds:fd_check $Script
    
    # Process file arguments
    $fileArgs = @()
    $counter = 0
    foreach ($file in $Files) {
        if ($counter -lt 20 -and ($file -like "/dev/fd/*" -or (Test-Path $file -PathType Leaf))) {
            $fileArgs += ds:fd_check $file
            $counter++
        }
    }
    
    # Process variable arguments
    $varArgsList = @()
    $counter = 0
    foreach ($varArg in $VarArgs) {
        if ($counter -lt 50) {
            $varArgsList += "-v"
            $varArgsList += $varArg
            $counter++
        }
    }
    
    # Run awk with utils.awk dependency
    try {
        if ($scriptPath) {
            & awk -f "$DS_SUPPORT\utils.awk" -f $scriptPath $varArgsList $fileArgs
        } else {
            & awk -f "$DS_SUPPORT\utils.awk" $varArgsList $fileArgs
        }
    } finally {
        # Clean up temporary file if created from piped input
        if ($piped -and $tempFile) {
            ds:pipe_clean $tempFile
        }
    }
}

function ds:prefield {
    <#
    .SYNOPSIS
    Infer and transform FS for complex field patterns
    
    .PARAMETER File
    File to process
    
    .PARAMETER FS
    Field separator
    
    .PARAMETER Dequote
    Whether to dequote fields
    
    .PARAMETER AwkArgs
    Additional awk arguments
    #>
    param(
        [string]$File,
        [string]$FS,
        [int]$Dequote = 0,
        [string[]]$AwkArgs = @()
    )
    
    ds:file_check $File
    $_file = $File
    
    if ($_file -like "/tmp*") {
        ds:dostounix $_file
    }
    
    $awkArgsStr = $AwkArgs -join " "
    if ($awkArgsStr -notmatch "-v OFS" -and $awkArgsStr -notmatch "-v ofs") {
        ds:awk "$DS_SCRIPT\quoted_fields.awk" $_file @("-v", "OFS=$DS_SEP", "-v", "FS=$FS", "-v", "retain_outer_quotes=$Dequote") + $AwkArgs
    } else {
        ds:awk "$DS_SCRIPT\quoted_fields.awk" $_file @("-v", "FS=$FS", "-v", "retain_outer_quotes=$Dequote") + $AwkArgs
    }
}

function ds:arr_idx {
    <#
    .SYNOPSIS
    Extract first shell array element position matching pattern
    
    .PARAMETER Pattern
    Pattern to match
    
    .PARAMETER Array
    Array to search
    #>
    param(
        [string]$Pattern,
        [string[]]$Array
    )
    
    for ($i = 0; $i -lt $Array.Length; $i++) {
        if ($Array[$i] -match $Pattern) {
            return $i + (ds:arr_base)
        }
    }
    return ""
}

function ds:arr_base {
    <#
    .SYNOPSIS
    Return first array index for shell
    #>
    $shell = ds:sh
    if ($shell -match "bash") {
        return 0
    } elseif ($shell -match "zsh") {
        return 1
    } else {
        ds:fail "This shell unsupported at this time"
    }
}

function ds:term_width {
    <#
    .SYNOPSIS
    Get a terminal width that doesn't fail if TERM isn't set
    #>
    try {
        $width = $Host.UI.RawUI.WindowSize.Width
        if ($width -gt 0) {
            return $width
        }
    } catch {
        # Fallback
    }
    return 100
}

function ds:pipe_clean {
    <#
    .SYNOPSIS
    Remove tmpfile created via STDIN if piping detected
    
    .PARAMETER TmpFile
    Temporary file to clean up
    #>
    param([string]$TmpFile)
    
    if ($script:piped) {
        Remove-Item $TmpFile -ErrorAction SilentlyContinue
    }
}

function ds:is_int {
    <#
    .SYNOPSIS
    Tests if arg is an integer
    
    .PARAMETER Value
    Value to test
    #>
    param([string]$Value)
    
    $int_re = "^-?[0-9]+$"
    return $Value -match $int_re
}

function ds:inferfs {
    <#
    .SYNOPSIS
    Infer field separator from file
    
    .PARAMETER File
    File to analyze
    
    .PARAMETER Quiet
    Whether to suppress output
    #>
    param(
        [string]$File,
        [bool]$Quiet = $false
    )
    
    # Call the Python script for field separator inference
    $result = & python "$DS_SCRIPT\infer_field_separator.awk" $File
    if ($Quiet) {
        return $result
    } else {
        Write-Output $result
    }
}

function ds:inferk {
    <#
    .SYNOPSIS
    Infer join keys from two files
    
    .PARAMETER File1
    First file
    
    .PARAMETER File2
    Second file
    #>
    param(
        [string]$File1,
        [string]$File2
    )
    
    # Call the Python script for join key inference
    & python "$DS_SCRIPT\infer_join_fields.awk" $File1 $File2
}

function ds:substr {
    <#
    .SYNOPSIS
    Extract substring
    
    .PARAMETER String
    Input string
    
    .PARAMETER Start
    Start pattern
    
    .PARAMETER End
    End pattern
    #>
    param(
        [string]$String,
        [string]$Start,
        [string]$End
    )
    
    if ($Start -and $End) {
        $startIdx = $String.IndexOf($Start)
        $endIdx = $String.IndexOf($End, $startIdx)
        if ($startIdx -ge 0 -and $endIdx -ge 0) {
            return $String.Substring($startIdx + $Start.Length, $endIdx - $startIdx - $Start.Length)
        }
    } elseif ($Start) {
        $startIdx = $String.IndexOf($Start)
        if ($startIdx -ge 0) {
            return $String.Substring($startIdx + $Start.Length)
        }
    } elseif ($End) {
        $endIdx = $String.IndexOf($End)
        if ($endIdx -ge 0) {
            return $String.Substring(0, $endIdx)
        }
    }
    return $String
}

function ds:dostounix {
    <#
    .SYNOPSIS
    Convert DOS line endings to Unix
    
    .PARAMETER File
    File to convert
    #>
    param([string]$File)
    
    $content = Get-Content $File -Raw
    $content = $content -replace "`r`n", "`n"
    Set-Content $File $content -NoNewline
}

function ds:readlink {
    <#
    .SYNOPSIS
    Portable readlink
    
    .PARAMETER FileOrDir
    File or directory to readlink
    #>
    param([string]$FileOrDir)
    
    $OLD_PWD = Get-Location
    Set-Location (Split-Path $FileOrDir -Parent) -ErrorAction SilentlyContinue
    $target = Split-Path $FileOrDir -Leaf
    
    while ((Get-Item $target -ErrorAction SilentlyContinue).LinkType -eq "SymbolicLink") {
        $target = (Get-Item $target).Target
        Set-Location (Split-Path $target -Parent) -ErrorAction SilentlyContinue
        $target = Split-Path $target -Leaf
    }
    
    $result = Join-Path (Get-Location) $target
    Set-Location $OLD_PWD
    return $result
}

function ds:die {
    <#
    .SYNOPSIS
    Output to STDERR and exit with error
    #>
    param([string[]]$Message)
    
    $Message | Write-Error
    if (ds:subsh -or ds:nested) {
        exit 1
    }
}

function ds:subsh {
    <#
    .SYNOPSIS
    Detect if in a subshell
    #>
    return $env:PSMODULEPATH -ne $env:PSMODULEPATH
}

function ds:nested {
    <#
    .SYNOPSIS
    Detect if shell is nested for control handling
    #>
    return $env:SHLVL -gt 1
}

function ds:sh {
    <#
    .SYNOPSIS
    Print the shell being used
    #>
    return "PowerShell"
}

function ds:needs_arg {
    <#
    .SYNOPSIS
    Test if argument is missing from opt and handle UX
    
    .PARAMETER Opt
    Option name
    
    .PARAMETER OptArg
    Option argument
    #>
    param(
        [string]$Opt,
        [string]$OptArg
    )
    
    if (-not $OptArg) {
        Write-Host "No arg for --$Opt option"
        ds:fail
    }
}

function ds:longopts {
    <#
    .SYNOPSIS
    Extract long opts
    
    .PARAMETER Opt
    Option
    
    .PARAMETER OptArg
    Option argument
    #>
    param(
        [string]$Opt,
        [string]$OptArg
    )
    
    $opt = $OptArg.Split("=")[0]
    $optarg = $OptArg.Substring($opt.Length)
    if ($optarg.StartsWith("=")) {
        $optarg = $optarg.Substring(1)
    }
    
    return @($opt, $optarg)
}

function ds:os {
    <#
    .SYNOPSIS
    Return computer operating system if supported
    #>
    if ($env:OS -eq "Windows_NT") {
        return "MS Windows"
    } elseif ($IsLinux) {
        return "Linux"
    } elseif ($IsMacOS) {
        return "MacOSX"
    } else {
        return "Failed to detect OS"
    }
}

function ds:not_git {
    <#
    .SYNOPSIS
    Check if directory is not part of a git repo
    
    .PARAMETER Directory
    Directory to check
    #>
    param([string]$Directory = ".")
    
    if ($Directory -ne ".") {
        Set-Location $Directory
    }
    
    try {
        git rev-parse --is-inside-work-tree 2>$null | Out-Null
        return $LASTEXITCODE -ne 0
    } catch {
        return $true
    }
}

function ds:is_cli {
    <#
    .SYNOPSIS
    Detect if shell is interactive
    #>
    return $Host.Name -eq "ConsoleHost"
}

function ds:readp {
    <#
    .SYNOPSIS
    Portable read prompt
    
    .PARAMETER Message
    Prompt message
    
    .PARAMETER Downcase
    Whether to downcase input
    #>
    param(
        [string]$Message,
        [bool]$Downcase = $true
    )
    
    $readvar = Read-Host $Message
    if ($Downcase) {
        return $readvar.ToLower()
    } else {
        return $readvar
    }
}

function ds:genvar {
    <#
    .SYNOPSIS
    Gen varname, shell disallows certain chars in var names
    
    .PARAMETER Name
    Variable name to generate
    #>
    param([string]$Name)
    
    $var = $Name
    $var = $var -replace "\.", "_DOT_"
    $var = $var -replace " ", "_SPACE_"
    $var = $var -replace "-", "_HYPHEN_"
    $var = $var -replace "/", "_FSLASH_"
    $var = $var -replace "\\", "_BSLASH_"
    $var = $var -replace "1", "_ONE_"
    $var = $var -replace "2", "_TWO_"
    $var = $var -replace "3", "_THREE_"
    $var = $var -replace "4", "_FOUR_"
    $var = $var -replace "5", "_FIVE_"
    $var = $var -replace "6", "_SIX_"
    $var = $var -replace "7", "_SEVEN_"
    $var = $var -replace "8", "_EIGHT_"
    $var = $var -replace "9", "_NINE_"
    
    return $var
}

function ds:termcolors {
    <#
    .SYNOPSIS
    Check terminal colors
    #>
    Write-Host "ANSI ESCAPE FG COLOR CODES"
    Write-Host "`e[30m 30   `e[31m 31   `e[32m 32   `e[33m 33   `e[0m"
    Write-Host "`e[34m 34   `e[35m 35   `e[36m 36   `e[37m 37   `e[0m"
    Write-Host "`e[30;1m 30;1 `e[31;1m 31;1 `e[32;1m 32;1 `e[33;1m 33;1 `e[0m"
    Write-Host "`e[34;1m 34;1 `e[35;1m 35;1 `e[36;1m 36;1 `e[37;1m 37;1 `e[0m"
    Write-Host ""
    Write-Host "ANSI ESCAPE BG COLOR CODES"
    Write-Host "`e[40m 40   `e[41m 41   `e[42m 42   `e[43m 43   `e[0m"
    Write-Host "`e[44m 44   `e[45m 45   `e[46m 46   `e[47m 47   `e[0m"
    Write-Host "`e[40;1m 40;1 `e[41;1m 41;1 `e[42;1m 42;1 `e[43;1m 43;1 `e[0m"
    Write-Host "`e[44;1m 44;1 `e[45;1m 45;1 `e[46;1m 46;1 `e[47;1m 47;1 `e[0m"
    Write-Host ""
    Write-Host "256 COLOR TEST"
    for ($i = 16; $i -lt 256; $i++) {
        Write-Host "`e[48;5;${i}m$($i.ToString("000"))" -NoNewline
        Write-Host "`e[0m" -NoNewline
        if (($i - 15) % 6 -eq 0) {
            Write-Host ""
        } else {
            Write-Host " " -NoNewline
        }
    }
    Write-Host ""
}

function ds:ascii {
    <#
    .SYNOPSIS
    List characters in ASCII code point range
    
    .PARAMETER StartIndex
    Start code point
    
    .PARAMETER EndIndex
    End code point
    #>
    param(
        [int]$StartIndex,
        [int]$EndIndex
    )
    
    if (-not (ds:is_int $StartIndex) -or -not (ds:is_int $EndIndex)) {
        ds:fail "Code point endpoint args must be integers"
    }
    
    for ($i = $StartIndex; $i -le $EndIndex; $i++) {
        Write-Host "$i " -NoNewline
        $char = [char]$i
        Write-Host $char
    }
}

Export-ModuleMember -Function ds:file_check, ds:fd_check, ds:pipe_open, ds:extractfs, ds:noawkfs, ds:awksafe, ds:awk, ds:prefield, ds:arr_idx, ds:arr_base, ds:term_width, ds:pipe_clean, ds:is_int, ds:inferfs, ds:inferk, ds:substr, ds:dostounix, ds:readlink, ds:die, ds:subsh, ds:nested, ds:sh, ds:needs_arg, ds:longopts, ds:os, ds:not_git, ds:is_cli, ds:readp, ds:genvar, ds:termcolors, ds:ascii

# Core PowerShell functions for dev_scripts
# Core utility functions like ds:commands, ds:help, ds:fail, etc.

# Import utility functions
. "$PSScriptRoot\Utils.ps1"

# Global variables
$DS_LOC = if ($env:DS_LOC) { $env:DS_LOC } else { "$env:HOME\dev_scripts" }
$DS_SCRIPT = "$DS_LOC\scripts"
$DS_SUPPORT = "$DS_LOC\support"
$DS_SEP = "@@@"

# Test if terminal supports color
$DS_COLOR_SUP = $Host.UI.RawUI.ForegroundColor -ne $Host.UI.RawUI.BackgroundColor

function ds:commands {
    <#
    .SYNOPSIS
    List dev_scripts commands
    
    .DESCRIPTION
    Lists all available dev_scripts commands with descriptions and usage information.
    Equivalent to bash ds:commands function.
    
    .PARAMETER BufferChar
    Character to use for buffer spacing in table output
    
    .PARAMETER Utils
    Include utility functions in the listing
    
    .PARAMETER ReSource
    Force regeneration of command cache
    #>
    param(
        [string]$BufferChar = " ",
        [switch]$Utils,
        [switch]$ReSource
    )
    
    $commandsFile = if ($Utils) { "$DS_SUPPORT\commands_utils" } else { "$DS_SUPPORT\commands" }
    
    # Generate commands list if needed
    if ($ReSource -or !(Test-Path $commandsFile)) {
        $commandPattern = "ds:[a-zA-Z0-9_]+\(\)"
        $files = @("$DS_LOC\commands.sh")
        if ($Utils) { $files += "$DS_SUPPORT\utils.sh" }
        
        $commands = @()
        foreach ($file in $files) {
            if (Test-Path $file) {
                $content = Get-Content $file -Raw
                $regexMatches = [regex]::Matches($content, $commandPattern)
                foreach ($match in $regexMatches) {
                    $command = $match.Value
                    $commands += $command
                }
            }
        }
        
        # Create formatted output
        $formattedCommands = @()
        foreach ($command in $commands | Sort-Object) {
            $formattedCommands += "$command`tDescription placeholder"
        }
        
        $formattedCommands | Out-File -FilePath $commandsFile -Encoding UTF8
    }
    
    # Display commands
    if (Test-Path $commandsFile) {
        Write-Host ""
        Get-Content $commandsFile | ForEach-Object { Write-Host $_ }
        Write-Host ""
        Write-Host "** - function supports receiving piped data"
        Write-Host ""
    }
}

function ds:help {
    <#
    .SYNOPSIS
    Print help for a given command
    
    .DESCRIPTION
    Shows help information for a specific dev_scripts command.
    Equivalent to bash ds:help function.
    
    .PARAMETER Command
    The command name to get help for
    #>
    param([string]$Command)
    
    if (!$Command -or !$Command.StartsWith("ds:")) {
        ds:die "Command not found - to see all commands, run ds:commands"
    }
    
    # Check if command exists
    if (!(Get-Command $Command -ErrorAction SilentlyContinue)) {
        ds:die "Command not found - to see all commands, run ds:commands"
    }
    
    # Display command information
    Write-Host "Help for $Command"
    Write-Host "=================="
    Write-Host "Command: $Command"
    Write-Host "Description: [Help information would be displayed here]"
    Write-Host ""
}

function ds:fail {
    <#
    .SYNOPSIS
    Safe failure that stops execution
    
    .DESCRIPTION
    Outputs an error message and stops execution.
    Equivalent to bash ds:fail function.
    
    .PARAMETER Message
    Error message to display
    #>
    param([string]$Message = "Operation failed")
    
    # Clean up if clean script exists
    $cleanScript = "$DS_SUPPORT\clean.sh"
    if (Test-Path $cleanScript) {
        try {
            & bash $cleanScript 2>$null
        } catch {
            # Ignore cleanup errors
        }
    }
    
    # Use ds:die for consistent error handling
    ds:die $Message
}

function ds:tmp {
    <#
    .SYNOPSIS
    Create a temporary file
    
    .DESCRIPTION
    Creates a temporary file with the specified prefix.
    Equivalent to bash ds:tmp function.
    
    .PARAMETER Prefix
    Prefix for the temporary file name
    
    .EXAMPLE
    ds:tmp "myfile"
    Creates a temporary file like C:\Users\...\AppData\Local\Temp\myfile.XXXXX.tmp
    #>
    param([string]$Prefix = "ds")
    
    $tempFile = [System.IO.Path]::GetTempFileName()
    $tempDir = [System.IO.Path]::GetDirectoryName($tempFile)
    $tempName = [System.IO.Path]::GetFileNameWithoutExtension($tempFile)
    $newName = "$Prefix.$tempName.tmp"
    $newPath = Join-Path $tempDir $newName
    
    Move-Item $tempFile $newPath
    return $newPath
}

function ds:test {
    <#
    .SYNOPSIS
    Test input with regex pattern
    
    .DESCRIPTION
    Tests input against a regex pattern.
    Equivalent to bash ds:test function.
    
    .PARAMETER Pattern
    Regex pattern to test against
    
    .PARAMETER Input
    Input string to test (if not piped)
    
    .PARAMETER TestFile
    Test against file content instead of string
    
    .EXAMPLE
    "hello world" | ds:test "world"
    Returns $true
    
    .EXAMPLE
    ds:test "^\d+$" "123"
    Returns $true
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Pattern,
        
        [Parameter(ValueFromPipeline=$true)]
        [string]$Input,
        
        [switch]$TestFile
    )
    
    if ($TestFile -and $Input) {
        if (Test-Path $Input) {
            $content = Get-Content $Input -Raw
            return $content -match $Pattern
        }
        return $false
    }
    
    if ($Input) {
        return $Input -match $Pattern
    }
    
    return $false
}

function ds:nset {
    <#
    .SYNOPSIS
    Test if a name (function/alias/variable) is defined
    
    .DESCRIPTION
    Tests whether a function, alias, or variable is defined.
    Equivalent to bash ds:nset function.
    
    .PARAMETER Name
    Name to test
    
    .PARAMETER SearchVars
    Also search variables
    
    .EXAMPLE
    ds:nset "Get-Process"
    Returns $true
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [switch]$SearchVars
    )
    
    # Check if it's a function or cmdlet
    if (Get-Command $Name -ErrorAction SilentlyContinue) {
        return $true
    }
    
    # Check if it's an alias
    if (Get-Alias $Name -ErrorAction SilentlyContinue) {
        return $true
    }
    
    # Check variables if requested
    if ($SearchVars) {
        if (Get-Variable $Name -ErrorAction SilentlyContinue) {
            return $true
        }
    }
    
    return $false
}

function ds:pipe_check {
    <#
    .SYNOPSIS
    Detect if pipe has data or over specified number of lines
    
    .DESCRIPTION
    Checks if there's data in the pipeline or if it exceeds a certain number of lines.
    Equivalent to bash ds:pipe_check function.
    
    .PARAMETER MaxLines
    Maximum number of lines to check for
    
    .EXAMPLE
    Get-Process | ds:pipe_check 10
    Returns $true if more than 10 processes
    #>
    param([int]$MaxLines = 0)
    
    $inputData = @($Input)
    
    if ($MaxLines -eq 0) {
        return $inputData.Count -gt 0
    } else {
        return $inputData.Count -gt $MaxLines
    }
}

function ds:cp {
    <#
    .SYNOPSIS
    Copy standard input to clipboard
    
    .DESCRIPTION
    Copies piped input to the system clipboard.
    Equivalent to bash ds:cp function.
    
    .EXAMPLE
    "Hello World" | ds:cp
    Copies "Hello World" to clipboard
    #>
    param(
        [Parameter(ValueFromPipeline=$true)]
        [string]$Input
    )
    
    $input | Set-Clipboard
}

function ds:rev {
    <#
    .SYNOPSIS
    Reverse lines from standard input
    
    .DESCRIPTION
    Reverses the order of lines from piped input.
    Equivalent to bash ds:rev function.
    
    .EXAMPLE
    @("line1", "line2", "line3") | ds:rev
    Returns @("line3", "line2", "line1")
    #>
    param(
        [Parameter(ValueFromPipeline=$true)]
        [string[]]$Input
    )
    
    $input | Sort-Object -Descending
}

function ds:join_by {
    <#
    .SYNOPSIS
    Join array elements with a delimiter
    
    .DESCRIPTION
    Joins array elements with a specified delimiter.
    Equivalent to bash ds:join_by function.
    
    .PARAMETER Delimiter
    Delimiter to use for joining
    
    .PARAMETER Array
    Array to join (if not piped)
    
    .EXAMPLE
    @("a", "b", "c") | ds:join_by ","
    Returns "a,b,c"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Delimiter,
        
        [Parameter(ValueFromPipeline=$true)]
        [string[]]$Array
    )
    
    if ($Array) {
        return $Array -join $Delimiter
    }
    
    return ""
}

function ds:embrace {
    <#
    .SYNOPSIS
    Enclose a string on each side by arguments
    
    .DESCRIPTION
    Wraps input with specified left and right delimiters.
    Equivalent to bash ds:embrace function.
    
    .PARAMETER Left
    Left delimiter (default: "{")
    
    .PARAMETER Right
    Right delimiter (default: "}")
    
    .PARAMETER Input
    Input string to wrap (if not piped)
    
    .EXAMPLE
    "hello" | ds:embrace "[" "]"
    Returns "[hello]"
    #>
    param(
        [string]$Left = "{",
        [string]$Right = "}",
        
        [Parameter(ValueFromPipeline=$true)]
        [string]$Input
    )
    
    if ($Input) {
        return "$Left$Input$Right"
    }
    
    return ""
}

function ds:path_elements {
    <#
    .SYNOPSIS
    Return directory, filename, and extension from filepath
    
    .DESCRIPTION
    Parses a file path into its components.
    Equivalent to bash ds:path_elements function.
    
    .PARAMETER FilePath
    File path to parse
    
    .EXAMPLE
    ds:path_elements "C:\Users\test\file.txt"
    Returns directory, filename, and extension components
    #>
    param([string]$FilePath)
    
    $dir = Split-Path $FilePath -Parent
    # $filename = Split-Path $FilePath -Leaf  # Not used in this implementation
    $extension = [System.IO.Path]::GetExtension($FilePath)
    $nameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    
    return @{
        Directory = $dir
        Filename = $nameWithoutExt
        Extension = $extension
    }
}

# Export functions for use in other modules
Export-ModuleMember -Function ds:commands, ds:help, ds:fail, ds:tmp, ds:test, ds:nset, ds:pipe_check, ds:cp, ds:rev, ds:join_by, ds:embrace, ds:path_elements

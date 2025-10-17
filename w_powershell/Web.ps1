# Web/search PowerShell functions for dev_scripts
# Web/search functions like ds:goog, ds:so, ds:jira, ds:websel, etc.

# Import core and utility functions
. "$PSScriptRoot\Core.ps1"
. "$PSScriptRoot\Utils.ps1"

function ds:websel {
    <#
    .SYNOPSIS
    Download and extract inner html by regex
    
    .DESCRIPTION
    Downloads a web page and extracts HTML content using regex patterns.
    Equivalent to bash ds:websel function.
    
    .PARAMETER URL
    URL to download
    
    .PARAMETER TagRegex
    Tag regex pattern (default: [a-z]+)
    
    .PARAMETER AttrsRegex
    Attributes regex pattern (default: [^>]*)
    
    .EXAMPLE
    ds:websel "https://example.com" "div" "class=.*"
    Extract div elements with class attributes
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$URL,
        
        [string]$TagRegex = "[a-z]+",
        [string]$AttrsRegex = "[^>]*"
    )
    
    try {
        $webClient = New-Object System.Net.WebClient
        $html = $webClient.DownloadString($URL)
        
        $pattern = "<$TagRegex.*?$AttrsRegex.*?>(.*?)</$TagRegex>"
        $regexMatches = [regex]::Matches($html, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        
        foreach ($match in $regexMatches) {
            $content = $match.Groups[1].Value.Trim()
            if ($content) {
                Write-Host $content
            }
        }
    } catch {
        Write-Error "Failed to download or parse URL: $_"
    }
}

function ds:goog {
    <#
    .SYNOPSIS
    Search Google
    
    .DESCRIPTION
    Opens Google search with the provided query.
    Equivalent to bash ds:goog function.
    
    .PARAMETER Query
    Search query
    
    .EXAMPLE
    ds:goog "PowerShell tutorial"
    Search Google for "PowerShell tutorial"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Query
    )
    
    $searchQuery = $Query -replace " ", "+"
    $searchUrl = "https://www.google.com/search?q=$searchQuery"
    
    try {
        Start-Process $searchUrl
    } catch {
        Write-Error "Failed to open browser: $_"
    }
}

function ds:so {
    <#
    .SYNOPSIS
    Search Stack Overflow
    
    .DESCRIPTION
    Opens Stack Overflow search with the provided query.
    Equivalent to bash ds:so function.
    
    .PARAMETER Query
    Search query
    
    .EXAMPLE
    ds:so "PowerShell error handling"
    Search Stack Overflow for "PowerShell error handling"
    #>
    param(
        [string]$Query = ""
    )
    
    if ($Query) {
        $searchQuery = $Query -replace " ", "+"
        $searchUrl = "https://stackoverflow.com/search?q=$searchQuery"
    } else {
        $searchUrl = "https://stackoverflow.com"
    }
    
    try {
        Start-Process $searchUrl
    } catch {
        Write-Error "Failed to open browser: $_"
    }
}

function ds:jira {
    <#
    .SYNOPSIS
    Open Jira at specified workspace issue / search
    
    .DESCRIPTION
    Opens Jira workspace with specified issue or search query.
    Equivalent to bash ds:jira function.
    
    .PARAMETER WorkspaceSubdomain
    Jira workspace subdomain
    
    .PARAMETER IssueOrQuery
    Issue number or search query
    
    .EXAMPLE
    ds:jira "mycompany" "PROJ-123"
    Open issue PROJ-123 in mycompany.atlassian.net
    
    .EXAMPLE
    ds:jira "mycompany" "bug report"
    Search for "bug report" in mycompany.atlassian.net
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$WorkspaceSubdomain,
        
        [string]$IssueOrQuery = ""
    )
    
    $baseUrl = "https://$WorkspaceSubdomain.atlassian.net"
    
    if ($IssueOrQuery) {
        if ($IssueOrQuery -match "^[A-Z]+-[0-9]+$") {
            $jiraUrl = "$baseUrl/browse/$IssueOrQuery"
        } else {
            $searchQuery = $IssueOrQuery -replace " ", "+"
            $jiraUrl = "$baseUrl/search/$searchQuery"
        }
    } else {
        $jiraUrl = $baseUrl
    }
    
    try {
        Start-Process $jiraUrl
    } catch {
        Write-Error "Failed to open browser: $_"
    }
}

# Export functions for use in other modules
Export-ModuleMember -Function ds:websel, ds:goog, ds:so, ds:jira

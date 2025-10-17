# Git operations PowerShell functions for dev_scripts
# Git operations like ds:git_cross_view, ds:git_purge_local, etc.

# Import core and utility functions
. "$PSScriptRoot\Core.ps1"
. "$PSScriptRoot\Utils.ps1"

function ds:git_cross_view {
    <#
    .SYNOPSIS
    Display table of git repos vs branches
    
    .DESCRIPTION
    Shows a cross-view table of git repositories and their branches.
    Equivalent to bash ds:git_cross_view function.
    
    .PARAMETER Options
    Additional options for the local_branch_view.sh script
    
    .EXAMPLE
    ds:git_cross_view
    Shows git repos vs branches table
    
    .EXAMPLE
    ds:git_cross_view "-s"
    Shows git repos vs branches with status
    #>
    param([string]$Options = "")
    
    # TODO: Implement native PowerShell version instead of calling bash script
    # This would provide better cross-platform compatibility and eliminate bash dependency
    $scriptPath = "$DS_SCRIPT\local_branch_view.sh"
    if (Test-Path $scriptPath) {
        & bash $scriptPath $Options.Split(' ')
    } else {
        ds:die "local_branch_view.sh script not found at $scriptPath"
    }
}

function ds:git_purge_local {
    <#
    .SYNOPSIS
    Purge branches from local git repos
    
    .DESCRIPTION
    Purges local branches from git repositories.
    Equivalent to bash ds:git_purge_local function.
    
    .PARAMETER ReposDir
    Directory containing git repositories (default: home directory)
    
    .EXAMPLE
    ds:git_purge_local
    Purge branches from repos in home directory
    
    .EXAMPLE
    ds:git_purge_local "C:\Projects"
    Purge branches from repos in C:\Projects
    #>
    param([string]$ReposDir = $env:HOME)
    
    # TODO: Implement native PowerShell version instead of calling bash script
    # This would provide better cross-platform compatibility and eliminate bash dependency
    $scriptPath = "$DS_SCRIPT\purge_local_branches.sh"
    if (Test-Path $scriptPath) {
        & bash $scriptPath $ReposDir
    } else {
        ds:die "purge_local_branches.sh script not found at $scriptPath"
    }
}

function ds:git_refresh {
    <#
    .SYNOPSIS
    Pull latest for all repos, run installs
    
    .DESCRIPTION
    Pulls the latest changes for all repositories and runs installs.
    Equivalent to bash ds:git_refresh function.
    
    .PARAMETER ReposDir
    Directory containing git repositories (default: home directory)
    
    .EXAMPLE
    ds:git_refresh
    Refresh all repos in home directory
    
    .EXAMPLE
    ds:git_refresh "C:\Projects"
    Refresh all repos in C:\Projects
    #>
    param([string]$ReposDir = $env:HOME)
    
    # TODO: Implement native PowerShell version instead of calling bash script
    # This would provide better cross-platform compatibility and eliminate bash dependency
    $scriptPath = "$DS_SCRIPT\local_env_refresh.sh"
    if (Test-Path $scriptPath) {
        & bash $scriptPath $ReposDir
    } else {
        ds:die "local_env_refresh.sh script not found at $scriptPath"
    }
}

function ds:git_checkout {
    <#
    .SYNOPSIS
    Checkout branch matching pattern
    
    .DESCRIPTION
    Checks out a branch matching the specified pattern.
    Equivalent to bash ds:git_checkout function.
    
    .PARAMETER BranchPattern
    Pattern to match branch names
    
    .PARAMETER NewBranch
    Create new branch if pattern doesn't match existing
    
    .EXAMPLE
    ds:git_checkout "feature*"
    Checkout branch matching "feature*"
    
    .EXAMPLE
    ds:git_checkout "main" -NewBranch
    Checkout or create "main" branch
    #>
    param(
        [string]$BranchPattern,
        [switch]$NewBranch
    )
    
    # TODO: Implement native PowerShell version instead of calling bash script
    # This would provide better cross-platform compatibility and eliminate bash dependency
    $scriptPath = "$DS_SCRIPT\git_checkout.sh"
    if (Test-Path $scriptPath) {
        $scriptArgs = @($BranchPattern)
        if ($NewBranch) { $scriptArgs += "t" }
        & bash $scriptPath $scriptArgs
    } else {
        ds:die "git_checkout.sh script not found at $scriptPath"
    }
}

function ds:git_squash {
    <#
    .SYNOPSIS
    Squash last n commits
    
    .DESCRIPTION
    Squashes the last n commits into one commit.
    Equivalent to bash ds:git_squash function.
    
    .PARAMETER NCommits
    Number of commits to squash (default: 1)
    
    .EXAMPLE
    ds:git_squash
    Squash last commit
    
    .EXAMPLE
    ds:git_squash 3
    Squash last 3 commits
    #>
    param([int]$NCommits = 1)
    
    # Check if we're in a git repository
    if (!(Test-Path ".git")) {
        ds:die "Not in a git repository"
    }
    
    # Validate input
    if ($NCommits -lt 1) {
        ds:die "Squash commits to arg must be an integer"
    }
    
    # Confirm action
    $confirm = Read-Host "Are you sure you want to squash the last $NCommits commit(s) on current branch?`n`nPlease confirm (y/n)"
    if ($confirm -ne "y") {
        Write-Host "No change made"
        return
    }
    
    try {
        $extent = $NCommits + 1
        git reset --soft "HEAD~$extent"
        $commitMessage = git log --format=%B --reverse "HEAD..HEAD@{1}"
        git commit --edit -m $commitMessage
    } catch {
        ds:die "Failed to squash commits: $_"
    }
}

function ds:git_time_stat {
    <#
    .SYNOPSIS
    Last local pull+change+commit times
    
    .DESCRIPTION
    Shows the last local pull, change, and commit times.
    Equivalent to bash ds:git_time_stat function.
    
    .EXAMPLE
    ds:git_time_stat
    Shows last pull, change, and commit times
    #>
    
    # Check if we're in a git repository
    if (!(Test-Path ".git")) {
        ds:die "Not in a git repository"
    }
    
    try {
        $repoPath = git rev-parse --show-toplevel
        
        # Last pull time
        $fetchHeadPath = Join-Path $repoPath ".git\FETCH_HEAD"
        if (Test-Path $fetchHeadPath) {
            $lastPull = (Get-Item $fetchHeadPath).LastWriteTime
            Write-Host ("Time of last pull:".PadRight(40) + $lastPull.ToString("ddd MMM dd HH:mm:ss yyyy zzz"))
        } else {
            Write-Host "No pulls found"
        }
        
        # Last change time
        $headPath = Join-Path $repoPath ".git\HEAD"
        if (Test-Path $headPath) {
            $lastChange = (Get-Item $headPath).LastWriteTime
            Write-Host ("Time of last local change:".PadRight(40) + $lastChange.ToString("ddd MMM dd HH:mm:ss yyyy zzz"))
        } else {
            Write-Host "No local changes found"
        }
        
        # Last commit time
        $lastCommit = git log -1 --format=%cd
        if ($lastCommit) {
            Write-Host ("Time of last commit found locally:".PadRight(40) + $lastCommit)
        } else {
            Write-Host "No local commit found"
        }
    } catch {
        ds:die "Failed to get git time statistics: $_"
    }
}

function ds:git_status {
    <#
    .SYNOPSIS
    Run git status for all repos
    
    .DESCRIPTION
    Runs git status for all repositories.
    Equivalent to bash ds:git_status function.
    
    .PARAMETER Options
    Additional options for the all_repo_git_status.sh script
    
    .EXAMPLE
    ds:git_status
    Shows git status for all repos
    #>
    param([string]$Options = "")
    
    # TODO: Implement native PowerShell version instead of calling bash script
    # This would provide better cross-platform compatibility and eliminate bash dependency
    $scriptPath = "$DS_SCRIPT\all_repo_git_status.sh"
    if (Test-Path $scriptPath) {
        & bash $scriptPath $Options.Split(' ')
    } else {
        ds:die "all_repo_git_status.sh script not found at $scriptPath"
    }
}

function ds:git_branch {
    <#
    .SYNOPSIS
    Run git branch for all repos
    
    .DESCRIPTION
    Runs git branch for all repositories.
    Equivalent to bash ds:git_branch function.
    
    .PARAMETER Options
    Additional options for the all_repo_git_branch.sh script
    
    .EXAMPLE
    ds:git_branch
    Shows git branches for all repos
    #>
    param([string]$Options = "")
    
    # TODO: Implement native PowerShell version instead of calling bash script
    # This would provide better cross-platform compatibility and eliminate bash dependency
    $scriptPath = "$DS_SCRIPT\all_repo_git_branch.sh"
    if (Test-Path $scriptPath) {
        & bash $scriptPath $Options.Split(' ')
    } else {
        ds:die "all_repo_git_branch.sh script not found at $scriptPath"
    }
}

function ds:git_add_com_push {
    <#
    .SYNOPSIS
    Add, commit with message, push
    
    .DESCRIPTION
    Adds all changes, commits with a message, and pushes to remote.
    Equivalent to bash ds:git_add_com_push function.
    
    .PARAMETER CommitMessage
    Commit message
    
    .PARAMETER Prompt
    Show prompt before proceeding (default: true)
    
    .EXAMPLE
    ds:git_add_com_push "Fix bug in login"
    Add, commit, and push with message
    
    .EXAMPLE
    ds:git_add_com_push "Update docs" -Prompt:$false
    Add, commit, and push without prompt
    #>
    param(
        [string]$CommitMessage,
        [bool]$Prompt = $true
    )
    
    # Check if we're in a git repository
    if (!(Test-Path ".git")) {
        ds:die "Not in a git repository"
    }
    
    # Clean up .DS_Store files on macOS
    if ($env:OS -eq "Darwin") {
        Get-ChildItem -Path . -Recurse -Name ".DS_Store" -Force | Remove-Item -Force
    }
    
    if ($Prompt) {
        git status
        Write-Host ""
        $confirm = Read-Host "Do you wish to proceed with add+commit+push? (y/n/new_commit_message)"
        
        if ($confirm -eq "n" -or $confirm -eq "N") {
            Write-Host "No add/commit/push made."
            return
        } elseif ($confirm -ne "y" -and $confirm -ne "Y") {
            $CommitMessage = $confirm
            $changeConfirm = Read-Host "Change message to `"$CommitMessage`" ? (y/n)"
            if ($changeConfirm -ne "y") {
                Write-Host "No add/commit/push made."
                return
            }
        }
    }
    
    try {
        $repoPath = git rev-parse --show-toplevel
        git add $repoPath
        
        if ($CommitMessage) {
            git commit -am $CommitMessage
        } else {
            git commit
        }
        
        # Check if upstream is set
        $upstreamCheck = git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null
        if ($LASTEXITCODE -ne 0) {
            $currentBranch = git rev-parse --abbrev-ref HEAD
            git push --set-upstream origin $currentBranch
            Write-Host "`nSet a new upstream branch for current branch."
        } else {
            git push
        }
    } catch {
        ds:die "Failed to add/commit/push: $_"
    }
}

function ds:git_recent {
    <#
    .SYNOPSIS
    Display commits sorted by recency
    
    .DESCRIPTION
    Shows commits sorted by recency.
    Equivalent to bash ds:git_recent function.
    
    .PARAMETER Refs
    Git refs to show (default: heads)
    
    .PARAMETER RunContext
    Context for running (default: display)
    
    .EXAMPLE
    ds:git_recent
    Shows recent commits
    
    .EXAMPLE
    ds:git_recent "tags" "parse"
    Shows recent tags in parse context
    #>
    param(
        [string]$Refs = "heads",
        [string]$RunContext = "display"
    )
    
    # Check if we're in a git repository
    if (!(Test-Path ".git")) {
        ds:die "Not in a git repository"
    }
    
    try {
        if ($RunContext -eq "display") {
            if ($DS_COLOR_SUP) {
                $format = '%(color:white)%(HEAD) %(color:bold yellow)%(refname:short)@@@%(color:bold green)%(committerdate:relative)@@@%(color:blue)%(subject)@@@%(color:magenta)%(authorname)%(color:reset)'
            } else {
                $format = '%(HEAD) %(refname:short)@@@%(committerdate:relative)@@@%(subject)@@@%(authorname)'
            }
            # TODO: Replace awk script with native PowerShell column formatting
            # This would eliminate the awk dependency and provide better cross-platform compatibility
            git for-each-ref --sort=-committerdate "refs/$Refs" --format=$format --color=always | 
                ForEach-Object { $_ -replace '@@@', $DS_SEP } |
                & "$DS_SCRIPT\fit_columns.awk" -F $DS_SEP
        } else {
            # Parse context - return extra field for further parsing
            if ($DS_COLOR_SUP) {
                $format = '%(color:white)%(HEAD) %(color:bold yellow)%(refname:short)@@@%(committerdate:short)@@@%(color:bold green)%(committerdate:relative)@@@%(color:cyan)%(objectname:short)@@@%(color:blue)%(subject)@@@%(color:magenta)%(authorname)%(color:reset)'
            } else {
                $format = '%(HEAD) %(refname:short)@@@%(committerdate:short)@@@%(committerdate:relative)@@@%(objectname:short)@@@%(subject)@@@%(authorname)'
            }
            git for-each-ref "refs/$Refs" --format=$format --color=always
        }
    } catch {
        ds:die "Failed to get recent commits: $_"
    }
}

function ds:git_recent_all {
    <#
    .SYNOPSIS
    Display recent commits for local repos
    
    .DESCRIPTION
    Shows recent commits for all local repositories.
    Equivalent to bash ds:git_recent_all function.
    
    .PARAMETER Refs
    Git refs to show (default: heads)
    
    .PARAMETER ReposDir
    Directory containing git repositories (default: home directory)
    
    .EXAMPLE
    ds:git_recent_all
    Shows recent commits for all repos in home directory
    
    .EXAMPLE
    ds:git_recent_all "heads" "C:\Projects"
    Shows recent commits for all repos in C:\Projects
    #>
    param(
        [string]$Refs = "heads",
        [string]$ReposDir = $env:HOME
    )
    
    $startDir = Get-Location
    $allRecent = ds:tmp "ds_git_recent_all"
    
    try {
        Set-Location $ReposDir
        
        $header = "repo@@@   branch@@@sortfield@@@commit time@@@hash@@@commit message@@@author"
        $header | Out-File -FilePath $allRecent -Encoding UTF8
        
        $dirs = Get-ChildItem -Directory
        foreach ($dir in $dirs) {
            if (Test-Path (Join-Path $dir.FullName ".git")) {
                try {
                    Set-Location $dir.FullName
                    $recentOutput = ds:git_recent $Refs "parse"
                    if ($recentOutput) {
                        $recentOutput | ForEach-Object { 
                            "$($dir.Name)@@@$_" 
                        } | Add-Content -Path $allRecent
                    }
                } catch {
                    # Skip repos with errors
                    continue
                }
            }
        }
        
        Write-Host ""
        # TODO: Replace awk script with native PowerShell column formatting
        # This would eliminate the awk dependency and provide better cross-platform compatibility
        # Sort by sortfield (column 3) and display
        Get-Content $allRecent | 
            Where-Object { $_ -notmatch "^repo@@@" } |
            Sort-Object { ($_ -split '@@@')[2] } -Descending |
            ForEach-Object { $_ -replace '@@@', $DS_SEP } |
            & "$DS_SCRIPT\fit_columns.awk" -F $DS_SEP
        
        Write-Host ""
    } finally {
        Set-Location $startDir
        if (Test-Path $allRecent) { Remove-Item $allRecent }
    }
}

function ds:git_graph {
    <#
    .SYNOPSIS
    Print colorful git history graph
    
    .DESCRIPTION
    Shows a colorful git history graph.
    Equivalent to bash ds:git_graph function.
    
    .EXAMPLE
    ds:git_graph
    Shows git history graph
    #>
    
    # Check if we're in a git repository
    if (!(Test-Path ".git")) {
        ds:die "Not in a git repository"
    }
    
    try {
        git log --all --decorate --oneline --graph
    } catch {
        ds:die "Failed to show git graph: $_"
    }
}

function ds:git_diff {
    <#
    .SYNOPSIS
    Diff shortcut for exclusions
    
    .DESCRIPTION
    Shows git diff with exclusions.
    Equivalent to bash ds:git_diff function.
    
    .PARAMETER FromObject
    Source object (commit, branch, file)
    
    .PARAMETER ToObject
    Target object (commit, branch, file)
    
    .PARAMETER Exclusions
    File patterns to exclude from diff
    
    .EXAMPLE
    ds:git_diff "main" "feature"
    Diff between main and feature branches
    
    .EXAMPLE
    ds:git_diff "HEAD~1" "HEAD" "*.log"
    Diff with log files excluded
    #>
    param(
        [string]$FromObject,
        [string]$ToObject,
        [string[]]$Exclusions = @()
    )
    
    # Check if we're in a git repository
    if (!(Test-Path ".git")) {
        ds:die "Not in a git repository"
    }
    
    try {
        if (Test-Path $FromObject) {
            # File diff
            git diff $FromObject $ToObject $Exclusions
        } else {
            # Object diff
            if ([string]::IsNullOrEmpty($FromObject) -or [string]::IsNullOrEmpty($ToObject)) {
                ds:die "Missing commit or branch objects"
            }
            
            $exclusionArgs = @()
            foreach ($exclusion in $Exclusions) {
                $exclusionArgs += ":(exclude)$exclusion"
            }
            
            Write-Host "git diff `"$FromObject`" `"$ToObject`" -b $($Exclusions -join ' ') -- . $($exclusionArgs -join ' ')"
            git diff $FromObject $ToObject -b $Exclusions -- . $exclusionArgs
        }
    } catch {
        ds:die "Failed to show git diff: $_"
    }
}

function ds:git_branch_refs {
    <#
    .SYNOPSIS
    List branches merged to a branch
    
    .DESCRIPTION
    Lists branches that have been merged to the specified branch.
    Equivalent to bash ds:git_branch_refs function.
    
    .PARAMETER Branch
    Target branch to check merges against (default: current branch)
    
    .PARAMETER Invert
    Show unmerged branches instead
    
    .EXAMPLE
    ds:git_branch_refs
    Shows branches merged to current branch
    
    .EXAMPLE
    ds:git_branch_refs "develop" -Invert
    Shows branches not merged to develop
    #>
    param(
        [string]$Branch,
        [switch]$Invert
    )
    
    # Check if we're in a git repository
    if (!(Test-Path ".git")) {
        ds:die "Not in a git repository"
    }
    
    try {
        $currentBranch = git branch --show-current
        if ([string]::IsNullOrEmpty($Branch)) {
            $Branch = $currentBranch
        }
        
        $localBranches = git for-each-ref --format='%(refname:short)' refs/heads | Sort-Object
        
        if ($Branch -notin $localBranches) {
            ds:die "Branch not found: $Branch"
        }
        
        # Fetch latest changes
        git fetch *>$null
        if ($LASTEXITCODE -ne 0) {
            ds:die "Failed to fetch."
        }
        
        # Check if working directory is clean
        $status = git status --porcelain
        if ($status.Length -eq 0) {
            git checkout $Branch *>$null
            git pull *>$null
        } else {
            Write-Warning "WARNING: Unable to pull latest version of $Branch as local untracked changes exist."
        }
        
        if ($Invert) {
            Write-Host "Unmerged branches on $Branch`:"
            Write-Host ""
            foreach ($tBranch in $localBranches) {
                $contains = git branch --contains $tBranch
                if ($contains -notmatch " $Branch") {
                    $logCheck = git log | Select-String $tBranch
                    if (!$logCheck) {
                        Write-Host $tBranch
                    }
                }
            }
        } else {
            Write-Host "Merged branches on $Branch (invert by passing -Invert):"
            Write-Host ""
            foreach ($tBranch in $localBranches) {
                $contains = git branch --contains $tBranch
                if ($contains -match " $Branch") {
                    Write-Host $tBranch
                } else {
                    $logCheck = git log | Select-String $tBranch
                    if ($logCheck) {
                        Write-Host $tBranch
                    }
                }
            }
        }
        
        # Return to original branch if needed
        if ($Branch -ne $currentBranch) {
            git checkout $currentBranch *>$null
        }
    } catch {
        ds:die "Failed to check branch refs: $_"
    }
}

function ds:git_word_diff {
    <#
    .SYNOPSIS
    Git word diff shortcut
    
    .DESCRIPTION
    Shows git diff with word-level changes highlighted.
    Equivalent to bash ds:git_word_diff function.
    
    .PARAMETER GitDiffArgs
    Additional arguments for git diff
    
    .EXAMPLE
    ds:git_word_diff
    Shows word diff for current changes
    
    .EXAMPLE
    ds:git_word_diff "HEAD~1"
    Shows word diff against previous commit
    #>
    param([string[]]$GitDiffArgs = @())
    
    # Check if we're in a git repository
    if (!(Test-Path ".git")) {
        ds:die "Not in a git repository"
    }
    
    try {
        git diff --word-diff-regex="[A-Za-z0-9. ]|[^[:space:]]" --word-diff=color $GitDiffArgs
    } catch {
        ds:die "Failed to show git word diff: $_"
    }
}

# Set up aliases
Set-Alias ds:gcv ds:git_cross_view
Set-Alias ds:gpl ds:git_purge_local
Set-Alias ds:grf ds:git_refresh
Set-Alias ds:gco ds:git_checkout
Set-Alias ds:gsq ds:git_squash
Set-Alias ds:gts ds:git_time_stat
Set-Alias ds:gs ds:git_status
Set-Alias ds:gb ds:git_branch
Set-Alias ds:gacp ds:git_add_com_push
Set-Alias ds:gr ds:git_recent
Set-Alias ds:gra ds:git_recent_all
Set-Alias ds:gg ds:git_graph
Set-Alias ds:gbr ds:git_branch_refs
Set-Alias ds:gwdf ds:git_word_diff

# Export functions for use in other modules
Export-ModuleMember -Function ds:git_cross_view, ds:git_purge_local, ds:git_refresh, ds:git_checkout, ds:git_squash, ds:git_time_stat, ds:git_status, ds:git_branch, ds:git_add_com_push, ds:git_recent, ds:git_recent_all, ds:git_graph, ds:git_diff, ds:git_branch_refs, ds:git_word_diff

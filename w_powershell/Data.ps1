# Data processing PowerShell functions for dev_scripts
# Data processing functions like ds:fit, ds:join, ds:pivot, ds:agg, etc.

# Import core and utility functions
. "$PSScriptRoot\Core.ps1"
. "$PSScriptRoot\Utils.ps1"

# Data processing functions
function ds:fit {
    <#
    .SYNOPSIS
    Fit fielded data in columns with dynamic width
    
    .DESCRIPTION
    Formats tabular data to fit terminal width with proper column alignment.
    Supports multiple files and various formatting options.
    
    .PARAMETER File
    File to process (or -h for help)
    
    .PARAMETER Prefield
    Whether to preprocess fields (default: true)
    
    .PARAMETER AwkArgs
    Additional awk arguments
    #>
    param(
        [string]$File = "",
        [switch]$Prefield = $true,
        [string[]]$AwkArgs = @()
    )
    
    $script:piped = $false
    $_file = $null
    
    if (ds:pipe_open $File) {
        $_file = ds:tmp "ds_fit"
        $script:piped = $true
        $input | Set-Content $_file
    } else {
        if ($File -match "^(-h|--help)$") {
            Get-Content "$DS_SCRIPT\fit_columns.awk" | Where-Object { $_ -match "^#( |$)" } | 
                ForEach-Object { $_ -replace "^#", "" } | Out-Host -Paging
            return
        }
        
        if ((Test-Path $File) -and $args.Count -gt 0 -and (Test-Path $args[0])) {
            $fls = @($File)
            while ($args.Count -gt 0 -and (Test-Path $args[0])) {
                $fls += $args[0]
                $args = $args[1..($args.Count-1)]
            }
            
            foreach ($fl in $fls) {
                if ($DS_COLOR_SUP) {
                    Write-Host "`n$fl" -ForegroundColor White
                } else {
                    Write-Host "`n$fl"
                }
                if (Test-Path $fl) {
                    ds:fit $fl @args
                }
            }
            return
        } else {
            ds:file_check $File
            $_file = ds:fd_check $File
            $args = $args[1..($args.Count-1)]
        }
    }
    
    if ($args.Count -gt 0 -and $args[0] -match "(f(alse)?|off)") {
        $pf_off = $true
        $args = $args[1..($args.Count-1)]
    } else {
        $prefield = ds:tmp "ds_fit_prefield"
    }
    
    $buffer = if ($env:DS_FIT_BUFFER) { $env:DS_FIT_BUFFER } else { 2 }
    $tty_size = ds:term_width
    $fstmp = ds:tmp "ds_extractfs"
    
    # Extract field separator
    $fs = ds:extractfs
    Set-Content $fstmp $fs
    $fs = Get-Content $fstmp
    Remove-Item $fstmp
    
    if (ds:awksafe) {
        $AwkArgs += @("-v", "awksafe=1", "-f", "$DS_SUPPORT\wcwidth.awk")
    } else {
        Write-Warning "AWK configuration does not support multibyte characters"
    }
    
    if ($pf_off) {
        ds:awk "$DS_SCRIPT\fit_columns.awk" @($_file, $_file) @("-v", "FS=$fs", "-v", "OFS=$fs", "-v", "tty_size=$tty_size", "-v", "buffer=$buffer", "-v", "file=$_file", "-v", "termcolor_support=$DS_COLOR_SUP") + $AwkArgs
    } else {
        ds:prefield $_file $fs 0 | Set-Content $prefield
        ds:awk "$DS_SCRIPT\fit_columns.awk" @($prefield, $prefield) @("-v", "FS=$DS_SEP", "-v", "OFS=$fs", "-v", "tty_size=$tty_size", "-v", "buffer=$buffer", "-v", "file=$_file", "-v", "termcolor_support=$DS_COLOR_SUP") + $AwkArgs
        Remove-Item $prefield
    }
    
    ds:pipe_clean $_file
}

function ds:join {
    <#
    .SYNOPSIS
    Join two datasets with any keyset
    
    .DESCRIPTION
    Performs various types of joins (inner, left, right, diff) between two datasets.
    Supports automatic key inference and multiple file extensions.
    
    .PARAMETER File1
    First file to join
    
    .PARAMETER File2
    Second file to join (or piped input)
    
    .PARAMETER JoinType
    Type of join (inner, left, right, diff)
    
    .PARAMETER Key
    Join key(s)
    
    .PARAMETER Prefield
    Whether to preprocess fields
    
    .PARAMETER AwkArgs
    Additional awk arguments
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$File1,
        [string]$File2 = "",
        [string]$JoinType = "",
        [string]$Key = "",
        [switch]$Prefield = $false,
        [string[]]$AwkArgs = @()
    )
    
    $script:piped = $false
    $f2 = $null
    
    if (ds:pipe_open $File2) {
        $f2 = ds:tmp "ds_jn"
        $script:piped = $true
        $input | Set-Content $f2
        ds:file_check $File1
        $f1 = $File1
    } else {
        if ($File1 -match "^(-h|--help)$") {
            Get-Content "$DS_SCRIPT\join.awk" | Where-Object { $_ -match "^#( |$)" } | 
                ForEach-Object { $_ -replace "^#", "" } | Out-Host -Paging
            return
        }
        ds:file_check $File1
        $f1 = ds:fd_check $File1
        ds:file_check $File2
        $f2 = ds:fd_check $File2
    }
    
    $arr_base = ds:arr_base
    
    # Handle multiple files
    $ext_jnf = @($f1, $f2)
    $ext_f = $ext_jnf.Length - 1 + $arr_base
    
    # Determine join type
    if ($JoinType) {
        if ($JoinType -match "^d") { $type = "diff" }
        elseif ($JoinType -match "^i") { $type = "inner" }
        elseif ($JoinType -match "^l") { $type = "left" }
        elseif ($JoinType -match "^r") { $type = "right" }
        
        if ($JoinType -notmatch "-" -and -not (ds:is_int $JoinType)) {
            $args = $args[1..($args.Count-1)]
        }
    }
    
    # Handle keys
    $merge = ds:arr_idx "merge" $args
    $has_keyarg = ds:arr_idx "k[12]?=" $args
    
    if ($merge -eq "" -and $has_keyarg -eq "") {
        if (ds:is_int $args[0]) {
            $k = $args[0]
            $args = $args[1..($args.Count-1)]
            if (ds:is_int $args[0]) {
                $k1 = $k
                $k2 = $args[0]
                $args = $args[1..($args.Count-1)]
            }
        } elseif (-not $args[0] -or $args[0] -match "^-") {
            $k = ds:inferk $f1 $f2
            if ($k -match " ") {
                $k2 = ds:substr $k " " ""
                $k1 = ds:substr $k "" " "
            }
        } else {
            $k = $args[0]
            $args = $args[1..($args.Count-1)]
        }
    }
    
    # Call the join script
    $scriptArgs = @($f1, $f2)
    if ($type) { $scriptArgs += $type }
    if ($k) { $scriptArgs += $k }
    if ($Prefield) { $scriptArgs += "prefield=t" }
    $scriptArgs += $AwkArgs
    
    ds:awk "$DS_SCRIPT\join.awk" $scriptArgs
    
    ds:pipe_clean $f2
}

function ds:pivot {
    <#
    .SYNOPSIS
    Pivot tabular data
    
    .DESCRIPTION
    Transforms tabular data by pivoting on specified keys and aggregating values.
    
    .PARAMETER File
    File to process
    
    .PARAMETER YKeys
    Y-axis keys
    
    .PARAMETER XKeys
    X-axis keys
    
    .PARAMETER ZKeys
    Z-axis keys (default: count_xy)
    
    .PARAMETER AggType
    Aggregation type
    
    .PARAMETER AwkArgs
    Additional awk arguments
    #>
    param(
        [string]$File = "",
        [string]$YKeys = "",
        [string]$XKeys = "",
        [string]$ZKeys = "count_xy",
        [string]$AggType = "",
        [string[]]$AwkArgs = @()
    )
    
    if ($File -match "^(-h|--help)$") {
        Get-Content "$DS_SCRIPT\pivot.awk" | Where-Object { $_ -match "^#( |$)" } | 
            ForEach-Object { $_ -replace "^#", "" } | Out-Host -Paging
        return
    }
    
    if (-not $File) {
        ds:file_check $File
    }
    
    $scriptArgs = @()
    if ($File) { $scriptArgs += $File }
    if ($YKeys) { $scriptArgs += $YKeys }
    if ($XKeys) { $scriptArgs += $XKeys }
    if ($ZKeys) { $scriptArgs += $ZKeys }
    if ($AggType) { $scriptArgs += $AggType }
    $scriptArgs += $AwkArgs
    
    ds:awk "$DS_SCRIPT\pivot.awk" $scriptArgs
}

function ds:agg {
    <#
    .SYNOPSIS
    Aggregate by index/pattern
    
    .DESCRIPTION
    Aggregates data by specified patterns with various aggregation functions.
    
    .PARAMETER File
    File to process (or -h for help)
    
    .PARAMETER RowAggs
    Row aggregation functions
    
    .PARAMETER ColAggs
    Column aggregation functions
    
    .PARAMETER AwkArgs
    Additional awk arguments
    #>
    param(
        [string]$File = "",
        [string]$RowAggs = "+",
        [string]$ColAggs = "+",
        [string[]]$AwkArgs = @()
    )
    
    if ($File -match "^(-h|--help)$") {
        Get-Content "$DS_SCRIPT\agg.awk" | Where-Object { $_ -match "^#( |$)" } | 
            ForEach-Object { $_ -replace "^#", "" } | Out-Host -Paging
        return
    }
    
    $scriptArgs = @()
    if ($File) { $scriptArgs += $File }
    $scriptArgs += $RowAggs
    $scriptArgs += $ColAggs
    $scriptArgs += $AwkArgs
    
    ds:awk "$DS_SCRIPT\agg.awk" $scriptArgs
}

function ds:sort {
    <#
    .SYNOPSIS
    Sort with inferred field sep of 1 char
    
    .DESCRIPTION
    Sorts data using Unix sort with inferred field separator.
    
    .PARAMETER UnixSortArgs
    Unix sort arguments
    
    .PARAMETER File
    File to sort
    #>
    param(
        [string[]]$UnixSortArgs = @(),
        [string]$File = ""
    )
    
    if ($File) {
        & sort $UnixSortArgs $File
    } else {
        $input | & sort $UnixSortArgs
    }
}

function ds:sortm {
    <#
    .SYNOPSIS
    Sort with inferred field sep of >=1 char
    
    .DESCRIPTION
    Sorts data with multi-character field separators using awk.
    
    .PARAMETER File
    File to sort
    
    .PARAMETER Keys
    Sort keys
    
    .PARAMETER Order
    Sort order (a=ascending, d=descending)
    
    .PARAMETER SortType
    Sort type
    
    .PARAMETER AwkArgs
    Additional awk arguments
    #>
    param(
        [string]$File = "",
        [string]$Keys = "",
        [ValidateSet("a", "d")]
        [string]$Order = "a",
        [string]$SortType = "",
        [string[]]$AwkArgs = @()
    )
    
    $scriptArgs = @()
    if ($File) { $scriptArgs += $File }
    if ($Keys) { $scriptArgs += $Keys }
    $scriptArgs += $Order
    if ($SortType) { $scriptArgs += $SortType }
    $scriptArgs += $AwkArgs
    
    ds:awk "$DS_SCRIPT\fields_qsort.awk" $scriptArgs           
}

function ds:transpose {
    <#
    .SYNOPSIS
    Transpose field values
    
    .DESCRIPTION
    Transposes rows and columns in tabular data.
    
    .PARAMETER File
    File to transpose
    
    .PARAMETER Prefield
    Whether to preprocess fields
    
    .PARAMETER AwkArgs
    Additional awk arguments
    #>
    param(
        [string]$File = "",
        [switch]$Prefield = $true,
        [string[]]$AwkArgs = @()
    )
    
    $scriptArgs = @()
    if ($File) { $scriptArgs += $File }
    if ($Prefield) { $scriptArgs += "prefield=t" }
    $scriptArgs += $AwkArgs
    
    ds:awk "$DS_SCRIPT\transpose.awk" $scriptArgs
}

function ds:hist {
    <#
    .SYNOPSIS
    Print histograms for all number fields in data
    
    .DESCRIPTION
    Creates histograms for numeric fields in the data.
    
    .PARAMETER File
    File to process
    
    .PARAMETER NBins
    Number of bins
    
    .PARAMETER BarLen
    Bar length
    
    .PARAMETER AwkArgs
    Additional awk arguments
    #>
    param(
        [string]$File = "",
        [int]$NBins = 10,
        [int]$BarLen = 50,
        [string[]]$AwkArgs = @()
    )
    
    $scriptArgs = @()
    if ($File) { $scriptArgs += $File }
    $scriptArgs += $NBins
    $scriptArgs += $BarLen
    $scriptArgs += $AwkArgs
    
    ds:awk "$DS_SCRIPT\hist.awk" $scriptArgs
}

function ds:graph {
    <#
    .SYNOPSIS
    Extract graph relationships from DAG base data
    
    .DESCRIPTION
    Extracts graph relationships from directed acyclic graph data.
    
    .PARAMETER File
    File to process
    #>
    param([string]$File = "")
    
    ds:awk "$DS_SCRIPT\graph.awk" $File
}

function ds:plot {
    <#
    .SYNOPSIS
    Get a scatter plot from two fields
    
    .DESCRIPTION
    Creates scatter plots from two numeric fields.
    
    .PARAMETER File
    File to process
    
    .PARAMETER FieldY
    Y field (default: 1)
    
    .PARAMETER FieldX
    X field (default: index)
    #>
    param(
        [string]$File = "",
        [int]$FieldY = 1,
        [string]$FieldX = "index"
    )
    
    ds:awk "$DS_SCRIPT\plot.awk" $File @("-v", "field_y=$FieldY", "-v", "field_x=$FieldX")
}

function ds:stagger {
    <#
    .SYNOPSIS
    Print tabular data in staggered rows
    
    .DESCRIPTION
    Formats tabular data in a staggered layout for better readability.
    
    .PARAMETER File
    File to process
    
    .PARAMETER StagSize
    Stagger size
    #>
    param(
        [string]$File = "",
        [int]$StagSize = 2
    )
    
    if ($File -match "^(-h|--help)$") {
        Get-Content "$DS_SCRIPT\stagger.awk" | Where-Object { $_ -match "^#( |$)" } | 
            ForEach-Object { $_ -replace "^#", "" } | Out-Host -Paging
        return
    }
    
    ds:awk "$DS_SCRIPT\stagger.awk" $File @("-v", "stag_size=$StagSize")
}

function ds:index {
    <#
    .SYNOPSIS
    Attach an index to lines from a file or STDIN
    
    .DESCRIPTION
    Adds line numbers or indices to input data.
    
    .PARAMETER File
    File to process
    
    .PARAMETER StartLine
    Starting line number (default: 1)
    #>
    param(
        [string]$File = "",
        [int]$StartLine = 1
    )
    
    ds:awk "$DS_SCRIPT\index.awk" $File @("-v", "startline=$StartLine")
}

function ds:matches {
    <#
    .SYNOPSIS
    Get match lines from two datasets
    
    .DESCRIPTION
    Finds matching lines between two datasets.
    
    .PARAMETER File1
    First file
    
    .PARAMETER File2
    Second file
    
    .PARAMETER AwkArgs
    Additional awk arguments
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$File1,
        [Parameter(Mandatory=$true)]
        [string]$File2,
        [string[]]$AwkArgs = @()
    )
    
    $scriptArgs = @($File1, $File2) + $AwkArgs
    ds:awk "$DS_SCRIPT\matches.awk" $scriptArgs
}

function ds:diff_fields {
    <#
    .SYNOPSIS
    Get elementwise diff of two datasets
    
    .DESCRIPTION
    Computes element-wise differences between two datasets.
    
    .PARAMETER File1
    First file
    
    .PARAMETER File2
    Second file
    
    .PARAMETER Op
    Operation (default: -)
    
    .PARAMETER ExcFields
    Exclude fields
    
    .PARAMETER Prefield
    Whether to preprocess fields
    
    .PARAMETER AwkArgs
    Additional awk arguments
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$File1,
        [string]$File2 = "",
        [string]$Op = "-",
        [int]$ExcFields = 0,
        [switch]$Prefield = $false,
        [string[]]$AwkArgs = @()
    )
    
    $scriptArgs = @($File1)
    if ($File2) { $scriptArgs += $File2 }
    $scriptArgs += $Op
    $scriptArgs += $ExcFields
    if ($Prefield) { $scriptArgs += "prefield=t" }
    $scriptArgs += $AwkArgs
    
    ds:awk "$DS_SCRIPT\diff_fields.awk" $scriptArgs
}

function ds:case {
    <#
    .SYNOPSIS
    Recase text data globally or in part
    
    .DESCRIPTION
    Changes case of text data with various options.
    
    .PARAMETER String
    String to process
    
    .PARAMETER ToCase
    Target case (proper, upper, lower, etc.)
    
    .PARAMETER Filter
    Filter pattern
    
    .PARAMETER AwkArgs
    Additional awk arguments
    #>
    param(
        [string]$String = "",
        [string]$ToCase = "proper",
        [string]$Filter = "",
        [string[]]$AwkArgs = @()
    )
    
    $scriptArgs = @()
    if ($String) { $scriptArgs += $String }
    $scriptArgs += $ToCase
    if ($Filter) { $scriptArgs += $Filter }
    $scriptArgs += $AwkArgs
    
    ds:awk "$DS_SCRIPT\case.awk" $scriptArgs
}

# Set up aliases
Set-Alias ds:jn ds:join
Set-Alias ds:t ds:transpose
Set-Alias ds:i ds:index
Set-Alias ds:s ds:sortm
Set-Alias ds:df ds:diff_fields

Export-ModuleMember -Function ds:fit, ds:join, ds:pivot, ds:agg, ds:sort, ds:sortm, ds:transpose, ds:hist, ds:graph, ds:plot, ds:stagger, ds:index, ds:matches, ds:diff_fields, ds:case
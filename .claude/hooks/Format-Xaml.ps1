#Requires -Version 5.1
<#
.SYNOPSIS
    Formats (or checks) the repository's authored XAML with XAML Styler using the committed
    per-project reference styles and the version pinned in .config/dotnet-tools.json.

.DESCRIPTION
    Single source of truth for XAML formatting in this repo. Used three ways:
      1. The Claude edit hook (.claude/hooks/post-tool-format-xaml.ps1) formats each edited file.
      2. Developers run it with no arguments to format all authored XAML.
      3. CI can run it with -Check to fail the build if any authored XAML is not conformant.

    Two projects live in this repository, each with its own committed reference style, and each
    file is formatted with the style that owns it:
      * PSADT-authored XAML (everything outside lib/) uses
        src/PSADT/PSADT.UserInterface/Settings.XamlStyler (UTF-8 BOM + CRLF working tree).
      * lib/Fluence.Wpf/** uses lib/Fluence.Wpf/Settings.XamlStyler and that project's
        LF + UTF-8 BOM policy, so subtree files stay byte-identical with upstream Fluence.Wpf.

    Generated XAML is excluded (it must not be reformatted):
      * lib/Fluence.Wpf/Fluence.Wpf/Properties/DesignTime.*.xaml - emitted byte-for-byte by
        DesignTimeResourceWriter; reformatting would break its drift guard.

.PARAMETER Check
    Verify formatting without modifying files. Exits 1 if any authored XAML is not conformant.

.PARAMETER Path
    One or more specific .xaml files to process. When omitted, all git-tracked .xaml are processed.

.EXAMPLE
    powershell .claude/hooks/Format-Xaml.ps1            # format all authored XAML
.EXAMPLE
    powershell .claude/hooks/Format-Xaml.ps1 -Check     # CI: fail if any authored XAML is unformatted
.EXAMPLE
    powershell .claude/hooks/Format-Xaml.ps1 -Path src/PSADT/PSADT.UserInterface.Interfaces/Fluent/FluentDialog.xaml
#>
[CmdletBinding()]
param(
    [switch]$Check,
    [string[]]$Path
)

$ErrorActionPreference = 'Stop'

# This script lives in .claude/hooks/, so the repo root is two levels up.
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$psadtConfig = Join-Path $repoRoot 'src\PSADT\PSADT.UserInterface\Settings.XamlStyler'
$fluenceConfig = Join-Path $repoRoot 'lib\Fluence.Wpf\Settings.XamlStyler'

if (-not (Test-Path -LiteralPath $psadtConfig)) {
    Write-Error "PSADT reference style not found: $psadtConfig"
    exit 1
}

function Get-RelativePath {
    param([string]$FullPath)
    $rootWithSep = $repoRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $full = [System.IO.Path]::GetFullPath($FullPath)
    if ($full.StartsWith($rootWithSep, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($rootWithSep.Length).Replace('\', '/')
    }
    return $full.Replace('\', '/')
}

# Generated XAML that must never be reformatted (matched on repo-relative, forward-slash path).
function Test-Excluded {
    param([string]$RelativePath)
    if ($RelativePath -match '(^|/)lib/Fluence\.Wpf/Fluence\.Wpf/Properties/DesignTime\.[^/]+\.xaml$') { return $true }
    return $false
}

# lib/Fluence.Wpf is a subtree of the upstream Fluence.Wpf repository and keeps that project's
# committed reference style and LF policy; everything else is PSADT-authored.
function Test-FluenceOwned {
    param([string]$RelativePath)
    return $RelativePath -match '(^|/)lib/Fluence\.Wpf/'
}

# Formats a single file in place: XAML Styler with the owning project's reference config, then a
# forced single UTF-8 BOM and the owning project's line endings (CRLF for PSADT working-tree files
# per the repo's text=auto checkout; LF for the Fluence subtree per upstream policy). UTF8.GetString
# keeps any leading BOM in the string, so strip it before re-emitting (otherwise a doubled BOM).
function Format-OneFile {
    param([string]$File, [string]$RelativePath)
    $fluenceOwned = Test-FluenceOwned -RelativePath $RelativePath
    $config = if ($fluenceOwned) { $fluenceConfig } else { $psadtConfig }
    if (-not (Test-Path -LiteralPath $config)) { throw "Reference style not found: $config" }
    & dotnet tool run xstyler -- -f $File -c $config -l Minimal *> $null
    if ($LASTEXITCODE -ne 0) { throw "xstyler failed on $File" }
    $bytes = [System.IO.File]::ReadAllBytes($File)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF).Replace("`r`n", "`n").Replace("`r", "`n")
    if (-not $fluenceOwned) {
        $text = $text.Replace("`n", "`r`n")
    }
    [System.IO.File]::WriteAllText($File, $text, (New-Object System.Text.UTF8Encoding($true)))
}

Push-Location $repoRoot
try {
    # Build the target list.
    if ($Path) {
        $candidates = $Path | ForEach-Object {
            if ([System.IO.Path]::IsPathRooted($_)) { [System.IO.Path]::GetFullPath($_) }
            else { [System.IO.Path]::GetFullPath((Join-Path $repoRoot $_)) }
        }
    }
    else {
        # -co --exclude-standard: tracked (cached) AND untracked-but-not-ignored, so a new
        # .xaml that has not been committed yet is still formatted/checked (avoids a false pass).
        $candidates = (& git -C $repoRoot ls-files -co --exclude-standard '*.xaml') | ForEach-Object { Join-Path $repoRoot $_ }
    }

    $targets = New-Object System.Collections.Generic.List[string]
    foreach ($candidate in $candidates) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
        $relative = Get-RelativePath -FullPath $candidate
        if (Test-Excluded -RelativePath $relative) { continue }
        $targets.Add($candidate)
    }

    if ($targets.Count -eq 0) {
        Write-Host 'No authored XAML files to process.'
        exit 0
    }

    $failed = New-Object System.Collections.Generic.List[string]

    foreach ($target in $targets) {
        $relative = Get-RelativePath -FullPath $target
        if ($Check) {
            # Non-destructive check: format a temp copy through the identical pipeline and compare.
            # (XAML Styler's own -p passive mode reports false positives, so we compare results.)
            $tmp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName() + ".xaml")
            Copy-Item -LiteralPath $target -Destination $tmp -Force
            try {
                Format-OneFile -File $tmp -RelativePath $relative
                $current = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
                $formatted = (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash
                if ($current -ne $formatted) { $failed.Add($relative) }
            }
            finally {
                Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            }
        }
        else {
            Format-OneFile -File $target -RelativePath $relative
        }
    }

    if ($Check) {
        if ($failed.Count -gt 0) {
            Write-Error ("XAML format check failed for $($failed.Count) file(s). Run 'powershell .claude/hooks/Format-Xaml.ps1' to fix:`n  " + ($failed -join "`n  "))
            exit 1
        }
        Write-Host "XAML format check passed ($($targets.Count) files)."
    }
    else {
        Write-Host "Formatted $($targets.Count) XAML files."
    }
}
finally {
    Pop-Location
}

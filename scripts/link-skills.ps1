#Requires -Version 5.1
<#
.SYNOPSIS
    Link this repository's skills into the Claude Code skills directory.

.DESCRIPTION
    Native Windows counterpart to scripts/link-skills.sh. Creates one link per
    skill directory in ~/.claude/skills (or $env:CLAUDE_CONFIG_DIR/skills).

    Directory junctions are used by default because Windows allows an
    unprivileged user to create them. Real symbolic links need either
    Developer Mode or an elevated shell; pass -Symbolic to use them anyway.

    Under WSL or Git Bash, use scripts/link-skills.sh instead.

.PARAMETER Command
    link (default), unlink, or status.

.PARAMETER Skill
    Skill names to act on. Default: every skill in skills/.

.PARAMETER Target
    Skills directory to link into. Default: $env:CLAUDE_CONFIG_DIR\skills,
    else ~\.claude\skills.

.PARAMETER Symbolic
    Create symbolic links instead of directory junctions.

.PARAMETER Force
    Replace links that point somewhere else. Never removes real files or
    directories.

.PARAMETER DryRun
    Print what would happen, change nothing.

.EXAMPLE
    .\scripts\link-skills.ps1

.EXAMPLE
    .\scripts\link-skills.ps1 link brainstorm verify

.EXAMPLE
    .\scripts\link-skills.ps1 status
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('link', 'unlink', 'status')]
    [string]$Command = 'link',

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$Skill,

    [string]$Target,
    [switch]$Symbolic,
    [switch]$Force,
    [switch]$DryRun
)

Set-StrictMode -Version 1.0
$ErrorActionPreference = 'Stop'

$repoRoot  = Split-Path -Parent $PSScriptRoot
$skillsSrc = Join-Path $repoRoot 'skills'
$failures  = 0

if (-not $Target) {
    $configDir = if ($env:CLAUDE_CONFIG_DIR) {
        $env:CLAUDE_CONFIG_DIR
    } elseif ($env:USERPROFILE) {
        Join-Path $env:USERPROFILE '.claude'
    } else {
        Join-Path $HOME '.claude'
    }
    $Target = Join-Path $configDir 'skills'
}

# Comparable form of a path: no \\?\ prefix, no trailing separator.
function ConvertTo-ComparablePath([string]$Path) {
    if (-not $Path) { return '' }
    return ($Path -replace '^\\\\\?\\', '').TrimEnd('\', '/')
}

# The path a link points at, or $null when the item is not a link.
function Get-LinkTarget([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (-not $item) { return $null }
    if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $null }

    $prop = $item.PSObject.Properties['Target']
    if (-not $prop -or -not $prop.Value) { return '<unreadable>' }

    $value = $prop.Value
    if ($value -is [array]) {
        if ($value.Count -eq 0) { return '<unreadable>' }
        $value = $value[0]
    }
    return ConvertTo-ComparablePath ([string]$value)
}

function Test-IsLink([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (-not $item) { return $false }
    return [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
}

# Deletes the link itself. Directory.Delete on a reparse point never touches
# the directory the link points at.
function Remove-Link([string]$Path) {
    if ($DryRun) { return }
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.PSIsContainer) {
        [System.IO.Directory]::Delete($Path, $false)
    } else {
        [System.IO.File]::Delete($Path)
    }
}

function New-SkillLink([string]$Path, [string]$Value) {
    if ($DryRun) { return }
    $type = if ($Symbolic) { 'SymbolicLink' } else { 'Junction' }
    try {
        New-Item -ItemType $type -Path $Path -Value $Value -ErrorAction Stop | Out-Null
    } catch {
        if ($Symbolic) {
            throw "$($_.Exception.Message) — creating symbolic links needs Developer Mode or an elevated shell. Drop -Symbolic to use a directory junction instead."
        }
        throw
    }
}

function Write-Result([string]$Tag, [string]$Color, [string]$Name, [string]$Message) {
    Write-Host $Tag -ForegroundColor $Color -NoNewline
    Write-Host (' ' + $Name.PadRight(16) + ' ' + $Message)
}
function Write-Ok  ([string]$n, [string]$m) { Write-Result ' ok ' 'Green'  $n $m }
function Write-Skip([string]$n, [string]$m) { Write-Result 'skip' 'Yellow' $n $m }
function Write-Fail([string]$n, [string]$m) { Write-Result 'fail' 'Red'    $n $m; $script:failures++ }

# "linked" when acting for real, "would link" during a dry run.
function Get-ActionWord([string]$Future, [string]$Past) {
    if ($DryRun) { return "would $Future" } else { return $Past }
}

function Get-AllSkills {
    Get-ChildItem -LiteralPath $skillsSrc -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') -PathType Leaf } |
        ForEach-Object { $_.Name }
}

function Invoke-Link([string]$Name) {
    $src = Join-Path $skillsSrc $Name
    $dst = Join-Path $Target $Name

    if (-not (Test-Path -LiteralPath (Join-Path $src 'SKILL.md') -PathType Leaf)) {
        Write-Fail $Name "no skills/$Name/SKILL.md in this repository"
        return
    }

    if (Test-IsLink $dst) {
        $current = Get-LinkTarget $dst
        if ($current -eq (ConvertTo-ComparablePath $src)) {
            Write-Ok $Name 'already linked'
            return
        }
        if (-not $Force) {
            Write-Skip $Name "link points to $current — rerun with -Force to replace"
            return
        }
        Remove-Link $dst
    } elseif (Test-Path -LiteralPath $dst) {
        Write-Fail $Name "$dst is a real file or directory — move it aside first"
        return
    }

    New-SkillLink $dst $src
    Write-Ok $Name ("{0} -> {1}" -f (Get-ActionWord 'link' 'linked'), $src)
}

function Invoke-Unlink([string]$Name) {
    $src = ConvertTo-ComparablePath (Join-Path $skillsSrc $Name)
    $dst = Join-Path $Target $Name

    if (Test-IsLink $dst) {
        $current = Get-LinkTarget $dst
        if ($current -eq $src -or $current -like ((ConvertTo-ComparablePath $skillsSrc) + '\*')) {
            Remove-Link $dst
            Write-Ok $Name (Get-ActionWord 'unlink' 'unlinked')
        } else {
            Write-Skip $Name "link points outside this repository ($current) — left alone"
        }
    } elseif (Test-Path -LiteralPath $dst) {
        Write-Skip $Name "$dst is a real file or directory — left alone"
    } else {
        Write-Ok $Name 'not linked'
    }
}

function Invoke-Status([string]$Name) {
    $src = ConvertTo-ComparablePath (Join-Path $skillsSrc $Name)
    $dst = Join-Path $Target $Name

    if (Test-IsLink $dst) {
        $current = Get-LinkTarget $dst
        if ($current -eq $src) { Write-Ok $Name 'linked' }
        else { Write-Skip $Name "linked to $current" }
    } elseif (Test-Path -LiteralPath $dst) {
        Write-Skip $Name "$dst exists and is not a link"
    } else {
        Write-Skip $Name 'not linked'
    }
}

# Links in the target directory that point into this repository but no longer
# have a source — left behind by a renamed or deleted skill.
function Write-StaleLinks {
    if (-not (Test-Path -LiteralPath $Target)) { return }
    $prefix = (ConvertTo-ComparablePath $skillsSrc) + '\'
    foreach ($entry in Get-ChildItem -LiteralPath $Target -Force) {
        if (-not (Test-IsLink $entry.FullName)) { continue }
        if (Test-Path -LiteralPath (Join-Path $skillsSrc $entry.Name) -PathType Container) { continue }
        $current = Get-LinkTarget $entry.FullName
        if ($current -like ($prefix + '*')) {
            Write-Skip $entry.Name "stale link into this repository — run: unlink $($entry.Name)"
        }
    }
}

if (-not (Test-Path -LiteralPath $skillsSrc -PathType Container)) {
    Write-Host "error: no skills\ directory in $repoRoot" -ForegroundColor Red
    exit 1
}

$names = if ($Skill) { $Skill } else { @(Get-AllSkills) }
if (-not $names -or $names.Count -eq 0) {
    Write-Host "error: no skills found in $skillsSrc" -ForegroundColor Red
    exit 1
}

Write-Host "repo:  $repoRoot"   -ForegroundColor DarkGray
Write-Host "into:  $Target"     -ForegroundColor DarkGray
if ($DryRun) { Write-Host 'mode:  dry run, nothing is written' -ForegroundColor DarkGray }
Write-Host ''

if ($Command -eq 'link' -and -not (Test-Path -LiteralPath $Target)) {
    if (-not $DryRun) { New-Item -ItemType Directory -Path $Target -Force | Out-Null }
}

foreach ($name in $names) {
    switch ($Command) {
        'link'   { Invoke-Link   $name }
        'unlink' { Invoke-Unlink $name }
        'status' { Invoke-Status $name }
    }
}

if ($Command -eq 'status') { Write-StaleLinks }

Write-Host ''
if ($failures -gt 0) {
    Write-Host "$failures skill(s) need attention." -ForegroundColor Red
    exit 1
}
if ($Command -ne 'status' -and -not $DryRun) {
    Write-Host 'Done. Start a new Claude Code session to pick up the changes.' -ForegroundColor DarkGray
}

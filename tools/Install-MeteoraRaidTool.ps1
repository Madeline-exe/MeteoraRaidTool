#Requires -Version 5.1
<#
.SYNOPSIS
    Downloads the latest Meteora Raid Tool build and installs it into the WoW Classic TBC AddOns folder.

.DESCRIPTION
    Pulls the most recent successful build (release or workflow artifact) from GitHub,
    unpacks it, and copies the MeteoraRaidTool folder into your WoW Classic Interface\AddOns directory.
    Safe to re-run — it removes the previous install before extracting the new one.

.PARAMETER WoWPath
    Path to your WoW Classic install folder (the one containing _classic_\). If omitted, the script
    tries the default Battle.net locations and falls back to a value cached at
    $env:USERPROFILE\.meteora-raid-tool.json.

.PARAMETER Repo
    GitHub repo as "owner/name". Defaults to the value of $env:METEORA_REPO if set, otherwise
    "CHANGE_ME/MeteoraRaidTool" — edit the default below or pass -Repo on the command line.

.PARAMETER Source
    Where to pull from: "release" (latest tagged release, default) or "artifact" (latest
    workflow run artifact — requires -Token with a GitHub PAT that has actions:read).

.PARAMETER Token
    GitHub Personal Access Token. Optional for public repos using -Source release, required
    for -Source artifact or private repos.

.EXAMPLE
    .\Install-MeteoraRaidTool.ps1
    Installs the latest release into the auto-detected WoW Classic folder.

.EXAMPLE
    .\Install-MeteoraRaidTool.ps1 -Source artifact -Token ghp_xxx
    Installs the latest CI build (no release tag needed) — best for active development.
#>
[CmdletBinding()]
param(
    [string]$WoWPath,
    [string]$Repo   = $(if ($env:METEORA_REPO) { $env:METEORA_REPO } else { 'Madeline-exe/MeteoraRaidTool' }),
    [ValidateSet('release','artifact')]
    [string]$Source = 'release',
    [string]$Token  = $env:GITHUB_TOKEN
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$AddonName  = 'MeteoraRaidTool'
$CacheFile  = Join-Path $env:USERPROFILE '.meteora-raid-tool.json'

function Write-Info ($msg) { Write-Host "[meteora] $msg" -ForegroundColor Cyan }
function Write-Ok   ($msg) { Write-Host "[meteora] $msg" -ForegroundColor Green }
function Write-Warn ($msg) { Write-Host "[meteora] $msg" -ForegroundColor Yellow }
function Write-Err  ($msg) { Write-Host "[meteora] $msg" -ForegroundColor Red }

Write-Info "Meteora Raid Tool installer started."
Write-Info "Repo: $Repo  | Source: $Source"

trap {
    Write-Err ""
    Write-Err "==== INSTALL FAILED ===="
    Write-Err $_.Exception.Message
    if ($_.InvocationInfo) {
        Write-Err ("at " + $_.InvocationInfo.PositionMessage)
    }
    Write-Err "========================"
    exit 1
}

function Resolve-WoWAddonsPath {
    param([string]$Explicit)

    if ($Explicit) {
        $candidate = $Explicit
    } elseif (Test-Path $CacheFile) {
        $cached = Get-Content $CacheFile -Raw | ConvertFrom-Json
        $candidate = $cached.WoWPath
        Write-Info "Using cached WoW path: $candidate"
    } else {
        $defaults = @(
            'C:\Program Files (x86)\World of Warcraft',
            'C:\Program Files\World of Warcraft',
            "$env:ProgramFiles(x86)\World of Warcraft",
            "$env:ProgramFiles\World of Warcraft"
        )
        $candidate = $defaults | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $candidate) {
            throw "Could not find WoW install. Pass -WoWPath ""C:\Path\To\World of Warcraft"""
        }
    }

    $tbc = Join-Path $candidate '_classic_\Interface\AddOns'
    if (-not (Test-Path $tbc)) {
        throw "AddOns folder not found at: $tbc. Make sure this is the WoW Classic TBC install root."
    }

    @{ WoWPath = $candidate } | ConvertTo-Json | Set-Content $CacheFile
    return $tbc
}

function Get-LatestReleaseAsset {
    param([string]$Repo, [string]$Token)
    $headers = @{ 'User-Agent' = 'MeteoraInstaller' }
    if ($Token) { $headers['Authorization'] = "Bearer $Token" }

    $api = "https://api.github.com/repos/$Repo/releases/latest"
    Write-Info "Fetching latest release from $Repo"
    $rel = Invoke-RestMethod -Uri $api -Headers $headers

    $asset = $rel.assets | Where-Object { $_.name -like "$AddonName-*.zip" -and $_.name -notlike '*-nolib*' } | Select-Object -First 1
    if (-not $asset) {
        $asset = $rel.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1
    }
    if (-not $asset) { throw "No .zip asset found in release $($rel.tag_name)" }

    return @{ Url = $asset.browser_download_url; Name = $asset.name; Tag = $rel.tag_name }
}

function Get-LatestArtifactAsset {
    param([string]$Repo, [string]$Token)
    if (-not $Token) { throw "Source 'artifact' requires -Token (PAT with actions:read)." }
    $headers = @{
        'User-Agent'    = 'MeteoraInstaller'
        'Authorization' = "Bearer $Token"
        'Accept'        = 'application/vnd.github+json'
    }

    Write-Info "Fetching latest workflow artifact from $Repo"
    $artifacts = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/actions/artifacts?per_page=20" -Headers $headers
    $artifact  = $artifacts.artifacts | Where-Object { -not $_.expired } | Select-Object -First 1
    if (-not $artifact) { throw "No active workflow artifacts found." }

    return @{ Url = $artifact.archive_download_url; Name = "$($artifact.name).zip"; Tag = "artifact #$($artifact.id)"; NeedsAuth = $true }
}

function Download-File {
    param([string]$Url, [string]$Out, [string]$Token, [bool]$NeedsAuth)
    $headers = @{ 'User-Agent' = 'MeteoraInstaller' }
    if ($Token -and $NeedsAuth) { $headers['Authorization'] = "Bearer $Token" }
    Invoke-WebRequest -Uri $Url -OutFile $Out -Headers $headers
}

function Install-Addon {
    param([string]$ZipPath, [string]$AddonsRoot)

    $tmp = Join-Path $env:TEMP "meteora-extract-$(Get-Random)"
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
        Expand-Archive -Path $ZipPath -DestinationPath $tmp -Force

        # CI artifact wraps the addon zip inside another zip; unwrap if needed
        $innerZip = Get-ChildItem -Path $tmp -Filter "$AddonName*.zip" -Recurse | Select-Object -First 1
        if ($innerZip) {
            Expand-Archive -Path $innerZip.FullName -DestinationPath $tmp -Force
        }

        $sourceFolder = Get-ChildItem -Path $tmp -Directory -Recurse |
            Where-Object { $_.Name -eq $AddonName } | Select-Object -First 1
        if (-not $sourceFolder) {
            throw "Could not locate $AddonName folder inside the downloaded package."
        }

        $dest = Join-Path $AddonsRoot $AddonName
        if (Test-Path $dest) {
            Write-Info "Removing previous install at $dest"
            Remove-Item -Path $dest -Recurse -Force
        }

        Write-Info "Copying $($sourceFolder.FullName) -> $dest"
        Copy-Item -Path $sourceFolder.FullName -Destination $AddonsRoot -Recurse -Force
    }
    finally {
        if (Test-Path $tmp) { Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# --- main ---

$addonsRoot = Resolve-WoWAddonsPath -Explicit $WoWPath
Write-Info "Target AddOns folder: $addonsRoot"

$info = if ($Source -eq 'release') {
    Get-LatestReleaseAsset -Repo $Repo -Token $Token
} else {
    Get-LatestArtifactAsset -Repo $Repo -Token $Token
}

$tmpZip = Join-Path $env:TEMP $info.Name
Write-Info "Downloading $($info.Name) ($($info.Tag))"
Download-File -Url $info.Url -Out $tmpZip -Token $Token -NeedsAuth:($info.NeedsAuth -eq $true)

try {
    Install-Addon -ZipPath $tmpZip -AddonsRoot $addonsRoot
    Write-Ok "Installed $AddonName from $($info.Tag)."
    Write-Info "Reload the WoW UI (/reload) or restart the client to pick up the new version."
}
finally {
    if (Test-Path $tmpZip) { Remove-Item -Path $tmpZip -Force -ErrorAction SilentlyContinue }
}

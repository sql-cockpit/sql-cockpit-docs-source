[CmdletBinding()]
param(
    [switch]$Once,
    [int]$PollSeconds = 1
)

$ErrorActionPreference = "Stop"

function Get-PythonCommand {
    $candidates = @(
        "C:\Users\Administrator.PEACOCKS\AppData\Local\Python\pythoncore-3.14-64\python.exe",
        "py",
        "python",
        "python3"
    )

    foreach ($candidate in $candidates) {
        if ($candidate -like "*.exe") {
            if (Test-Path $candidate) {
                return $candidate
            }

            continue
        }

        try {
            $command = Get-Command $candidate -ErrorAction Stop
            if ($null -ne $command -and -not [string]::IsNullOrWhiteSpace($command.Source)) {
                return $command.Source
            }
        }
        catch {
        }
    }

    throw "Could not find a usable Python interpreter for MkDocs."
}

function Ensure-GlightboxPlugin {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PythonCommand
    )

    & $PythonCommand -m pip show mkdocs-glightbox *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-BuildLog "mkdocs-glightbox is already installed."
        return
    }

    Write-BuildLog "mkdocs-glightbox is missing. Installing..."
    & $PythonCommand -m pip install "mkdocs-glightbox>=0.5.2"
}

function Write-BuildLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ConsoleColor]$Color = [ConsoleColor]::Cyan
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [DOCS-BUILD] $Message" -ForegroundColor $Color
}

function Invoke-DocsBuild {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PythonCommand,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    Push-Location $RepoRoot
    try {
        Ensure-GlightboxPlugin -PythonCommand $PythonCommand
        Write-BuildLog "Refreshing generated configuration docs."
        powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\generate_config_docs.ps1

        $configPath = ".\mkdocs.yml"
        if (Test-Path -LiteralPath ".\.mkdocs.compat.local.yml" -PathType Leaf) {
            $configPath = ".\.mkdocs.compat.local.yml"
            Write-BuildLog "Using compatibility MkDocs config (.mkdocs.compat.local.yml)."
        }

        Write-BuildLog "Building MkDocs site."
        & $PythonCommand -m mkdocs build -f $configPath
    }
    finally {
        Pop-Location
    }
}

function Get-WatchedFileState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $docsRoot = Join-Path -Path $RepoRoot -ChildPath "docs"
    $mkdocsConfig = Join-Path -Path $RepoRoot -ChildPath "mkdocs.yml"

    $items = @()

    if (Test-Path -LiteralPath $mkdocsConfig -PathType Leaf) {
        $items += Get-Item -LiteralPath $mkdocsConfig
    }

    if (Test-Path -LiteralPath $docsRoot -PathType Container) {
        $items += Get-ChildItem -LiteralPath $docsRoot -Recurse -File
    }

    return @(
        $items |
            Sort-Object FullName |
            ForEach-Object {
                "{0}|{1}|{2}" -f $_.FullName, $_.Length, $_.LastWriteTimeUtc.Ticks
            }
    ) -join "`n"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$pythonCommand = Get-PythonCommand

if ($PollSeconds -lt 1) {
    throw "-PollSeconds must be 1 or greater."
}

Invoke-DocsBuild -PythonCommand $pythonCommand -RepoRoot $repoRoot

if ($Once) {
    exit 0
}

$lastState = Get-WatchedFileState -RepoRoot $repoRoot
Write-BuildLog "Watching docs sources for changes. Press Ctrl+C to stop." -Color Green

while ($true) {
    Start-Sleep -Seconds $PollSeconds

    $currentState = Get-WatchedFileState -RepoRoot $repoRoot
    if ($currentState -eq $lastState) {
        continue
    }

    Write-BuildLog "Change detected. Rebuilding docs."

    try {
        Invoke-DocsBuild -PythonCommand $pythonCommand -RepoRoot $repoRoot
    }
    catch {
        Write-BuildLog ("Build failed: {0}" -f $_.Exception.Message) -Color Red
    }
    finally {
        $lastState = Get-WatchedFileState -RepoRoot $repoRoot
    }
}

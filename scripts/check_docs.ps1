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
        Write-Host "[DOCS-CHECK] mkdocs-glightbox is already installed."
        return
    }

    Write-Host "[DOCS-CHECK] mkdocs-glightbox is missing. Installing..."
    & $PythonCommand -m pip install "mkdocs-glightbox>=0.5.2"
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$pythonCommand = Get-PythonCommand
Push-Location $repoRoot
try {
    Ensure-GlightboxPlugin -PythonCommand $pythonCommand
    powershell -NoProfile -ExecutionPolicy Bypass -File .\docs\scripts\generate_config_docs.ps1
    & $pythonCommand -m mkdocs build --strict
}
finally {
    Pop-Location
}

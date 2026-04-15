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

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$pythonCommand = Get-PythonCommand
Push-Location $repoRoot
try {
    powershell -NoProfile -ExecutionPolicy Bypass -File .\docs\scripts\generate_config_docs.ps1
    & $pythonCommand -m mkdocs build --strict
}
finally {
    Pop-Location
}

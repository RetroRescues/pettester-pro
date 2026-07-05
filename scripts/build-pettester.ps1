param(
    [string]$Assembler = $env:CBMASM,
    [string]$VicePetDir = $env:PETTESTER_VICE_PET_DIR
)

$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not (Test-Path (Join-Path $repo "src\pettester.asm"))) {
    throw "Cannot find repository root from script path."
}

function Resolve-Cbmasm {
    param([string]$Requested)

    if ($Requested) {
        return $Requested
    }

    $command = Get-Command cbmasm -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $legacy = Join-Path (Split-Path -Parent (Split-Path -Parent $repo)) "pettester\tools\cbmasm.exe"
    if (Test-Path -LiteralPath $legacy) {
        return $legacy
    }

    throw "cbmasm not found. Install cbmasm, add it to PATH, or set CBMASM to the executable path."
}

function Build-Rom {
    param(
        [string]$SourceName,
        [string]$OutputName
    )

    $assemblerPath = Resolve-Cbmasm $Assembler
    $source = Join-Path $repo "src\$SourceName"
    $outputDir = Join-Path $repo "roms"
    $output = Join-Path $outputDir $OutputName
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

    Push-Location $repo
    try {
        & $assemblerPath -output plain $source $output
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }
    finally {
        Pop-Location
    }

    $items = @($output)
    if ($VicePetDir) {
        New-Item -ItemType Directory -Path $VicePetDir -Force | Out-Null
        $viceOutput = Join-Path $VicePetDir $OutputName
        Copy-Item -LiteralPath $output -Destination $viceOutput -Force
        $items += $viceOutput
    }

    Get-Item $items | Select-Object FullName, Length
}

Build-Rom "pettester.asm" "pettester.bin"

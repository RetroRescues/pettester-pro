$scriptRepo = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = (Get-Location).ProviderPath
if (-not (Test-Path (Join-Path $repo "pettester-80.vrs"))) {
    $repo = $scriptRepo
}
$viceRoot = Split-Path -Parent (Split-Path -Parent $repo)
$xpet = Join-Path $viceRoot "xpet.exe"
$romset = Join-Path $repo "pettester-80.vrs"

& $xpet -default -model 8032 -romsetfile $romset

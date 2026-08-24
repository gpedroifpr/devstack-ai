param(
  [string]$Flutter = "C:\src\flutter\bin\flutter.bat"
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$envPath = Join-Path $projectRoot ".env"

if (-not (Test-Path $envPath)) {
  throw "Arquivo .env nao encontrado em $projectRoot"
}

$config = @{}

Get-Content $envPath | ForEach-Object {
  $line = $_.Trim()

  if (-not $line -or $line.StartsWith("#")) {
    return
  }

  $parts = $line -split "=", 2
  if ($parts.Count -ne 2) {
    return
  }

  $key = $parts[0].Trim()
  $value = $parts[1].Trim()

  if (
    ($value.StartsWith('"') -and $value.EndsWith('"')) -or
    ($value.StartsWith("'") -and $value.EndsWith("'"))
  ) {
    $value = $value.Substring(1, $value.Length - 2)
  }

  $config[$key] = $value
}

$requiredKeys = @(
  "GEMINI_API_KEY",
  "FIREBASE_API_KEY",
  "FIREBASE_AUTH_DOMAIN",
  "FIREBASE_PROJECT_ID",
  "FIREBASE_STORAGE_BUCKET",
  "FIREBASE_MESSAGING_SENDER_ID",
  "FIREBASE_APP_ID"
)

$missingKeys = $requiredKeys | Where-Object {
  -not $config.ContainsKey($_) -or [string]::IsNullOrWhiteSpace($config[$_])
}

if ($missingKeys.Count -gt 0) {
  throw "Variaveis ausentes ou vazias no .env: $($missingKeys -join ', ')"
}

$buildArgs = @("build", "web", "--release")

foreach ($key in $requiredKeys) {
  $buildArgs += "--dart-define=$key=$($config[$key])"
}

Write-Host "Gerando build/web com variaveis do .env..."
& $Flutter @buildArgs

if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

Write-Host "Build pronto. Agora publique com: firebase deploy"

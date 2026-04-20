# Запуск webhook-версии бота на Windows (PowerShell)
# Аналог start.sh (mac/linux)

$ErrorActionPreference = "Stop"

function Load-DotEnv([string]$path) {
  if (-not (Test-Path $path)) {
    Write-Host "No .env file found at $path (skipping)"
    return
  }

  Get-Content $path | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { return }

    # поддержка KEY=VALUE
    $pair = $line -split "=", 2
    if ($pair.Length -ne 2) { return }

    $key = $pair[0].Trim()
    $value = $pair[1].Trim()

    # убрать кавычки если есть
    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
      $value = $value.Substring(1, $value.Length - 2)
    }

    [System.Environment]::SetEnvironmentVariable($key, $value, "Process")
  }
}

function Stop-ProcessByNameSafe([string]$name) {
  Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

function Stop-RubyByScriptNameSafe([string]$scriptNamePart) {
  # Находим ruby-процессы, где в командной строке есть нужное имя скрипта
  Get-CimInstance Win32_Process -Filter "Name='ruby.exe'" |
    Where-Object { $_.CommandLine -match [Regex]::Escape($scriptNamePart) } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

# 1) Остановить старые процессы
Stop-RubyByScriptNameSafe "sinatra_app.rb"
Stop-ProcessByNameSafe "ngrok"
Stop-ProcessByNameSafe "puma"

# 2) Подгрузить .env в переменные окружения
Load-DotEnv ".\.env"

# 3) Запустить ngrok
# Требования:
# - ngrok должен быть установлен и доступен в PATH (команда ngrok должна работать)
Write-Host "Starting ngrok http 4567 ..."
$ngrok = Start-Process -FilePath "ngrok" -ArgumentList "http", "4567" -PassThru

Start-Sleep -Seconds 3

# 4) Запустить Sinatra
Write-Host "Starting Sinatra app (sinatra_app.rb) ..."
$app = Start-Process -FilePath "bundle" -ArgumentList "exec", "ruby", "sinatra_app.rb" -PassThru

Start-Sleep -Seconds 2

# 5) Обновить webhook
Write-Host "Updating webhook ..."
& bundle exec ruby .\app\update_webhook.rb

Write-Host ""
Write-Host "Running."
Write-Host "ngrok PID: $($ngrok.Id)"
Write-Host "app   PID: $($app.Id)"
Write-Host "Press Ctrl+C to stop. (Then close ngrok window if needed.)"

try {
  Wait-Process -Id $app.Id
}
finally {
  # при остановке — чистим процессы
  Write-Host "Stopping..."
  Stop-Process -Id $app.Id -Force -ErrorAction SilentlyContinue
  Stop-Process -Id $ngrok.Id -Force -ErrorAction SilentlyContinue
}
param([ValidateSet('editor', 'play', 'test', 'export', 'serve', 'content')][string]$Action = 'play')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godotPath = Join-Path $env:LOCALAPPDATA 'MoonveilTools\Godot_v4.5.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $godotPath)) {
    $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
    if ($godotCommand) { $godotPath = $godotCommand.Source }
    else { throw 'Install Godot 4.5.2 or put godot on PATH. See README.md.' }
}
Push-Location -LiteralPath $projectRoot
try {
    switch ($Action) {
        'editor' { & $godotPath --editor --path $projectRoot }
        'play' { & $godotPath --path $projectRoot }
        'test' { & $godotPath --headless --path $projectRoot --script tests/action_tests.gd }
        'content' { & $godotPath --path $projectRoot tools/content_editor.tscn }
        'export' {
            New-Item -ItemType Directory -Force -Path 'build/windows/Music' | Out-Null
            New-Item -ItemType File -Force -Path 'build/.gdignore' | Out-Null
            & $godotPath --headless --path $projectRoot --export-release 'Windows Desktop' build/windows/SailorMoon.exe
            if ($LASTEXITCODE -eq 0) {
                Copy-Item -LiteralPath 'docs/GODOT_LICENSE.txt' -Destination 'build/windows/GODOT_LICENSE.txt'
                Copy-Item -LiteralPath 'assets/fonts/OFL.txt' -Destination 'build/windows/NOTO_LICENSE.txt'
                Copy-Item -LiteralPath 'assets/fonts/Cormorant-OFL.txt' -Destination 'build/windows/CORMORANT_LICENSE.txt'
                Copy-Item -LiteralPath 'Music/audio.json' -Destination 'build/windows/Music/audio.json'
                Get-ChildItem -LiteralPath 'Music' -File | Where-Object { $_.Extension -in '.mp3', '.ogg', '.wav' } | ForEach-Object {
                    Copy-Item -LiteralPath $_.FullName -Destination 'build/windows/Music'
                }
                Copy-Item -LiteralPath 'docs/MUSIC_QUICKSTART.md' -Destination 'build/windows/MUSIC_QUICKSTART.md'
                Copy-Item -LiteralPath 'README.md' -Destination 'build/windows/README.md'
                Copy-Item -LiteralPath 'docs/GUARDIAN_MOTION.md' -Destination 'build/windows/GUARDIAN_MOTION.md'
            }
        }
        'serve' {
            $pythonPath = Join-Path $env:LOCALAPPDATA 'Python\pythoncore-3.14-64\python.exe'
            if (-not (Test-Path -LiteralPath $pythonPath)) { $pythonPath = 'python' }
            & $pythonPath tools/serve.py
        }
    }
    if ($LASTEXITCODE -ne 0) { throw "Command failed: $LASTEXITCODE" }
} finally { Pop-Location }

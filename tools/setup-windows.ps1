# CREOS — installation du poste de développement (Windows 10/11)
# Lancer depuis le dossier du projet, dans PowerShell :
#   powershell -ExecutionPolicy Bypass -File tools\setup-windows.ps1
#
# Installe : Git, Node.js, uv, Blender, Godot 4.7.2, Claude Code
# Configure pour Claude Code : MCP Godot + MCP Blender

$ErrorActionPreference = "Stop"
$GodotVersion = "4.7.2"
$GodotDir = Join-Path $env:LOCALAPPDATA "Godot\$GodotVersion"
$GodotExe = Join-Path $GodotDir "Godot_v$GodotVersion-stable_win64.exe"
$ProjectDir = Split-Path -Parent $PSScriptRoot

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

function Install-Winget($id) {
    $installed = winget list --id $id -e 2>$null | Select-String $id
    if ($installed) { Write-Host "  deja installe : $id" }
    else { winget install --id $id -e --accept-source-agreements --accept-package-agreements }
}

Step "Logiciels (winget)"
Install-Winget "Git.Git"
Install-Winget "OpenJS.NodeJS.LTS"
Install-Winget "astral-sh.uv"
Install-Winget "BlenderFoundation.Blender"
# Recharge le PATH pour cette fenetre
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

Step "Godot $GodotVersion"
if (-not (Test-Path $GodotExe)) {
    New-Item -ItemType Directory -Force -Path $GodotDir | Out-Null
    $zip = Join-Path $env:TEMP "godot.zip"
    Invoke-WebRequest "https://github.com/godotengine/godot/releases/download/$GodotVersion-stable/Godot_v$GodotVersion-stable_win64.exe.zip" -OutFile $zip
    Expand-Archive $zip -DestinationPath $GodotDir -Force
    Remove-Item $zip
}
Write-Host "  Godot : $GodotExe"
[Environment]::SetEnvironmentVariable("GODOT_PATH", $GodotExe, "User")
$env:GODOT_PATH = $GodotExe

Step "Claude Code"
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
    $env:Path += ";" + (Join-Path $env:USERPROFILE ".local\bin")
}
claude --version

Step "MCP Godot (Coding-Solo/godot-mcp)"
Push-Location $ProjectDir
claude mcp remove godot -s local 2>$null
claude mcp add godot -s local -e GODOT_PATH=$GodotExe -e DEBUG=true -- cmd /c npx -y @coding-solo/godot-mcp

Step "MCP Blender (mcp-for-blender) : installe l'addon Blender et l'ajoute a Claude Code"
Write-Host "  Quand il demande quelles applis configurer, coche 'Claude Code'."
uvx mcp-for-blender setup

Step "Import des assets et tests"
& $GodotExe --headless --path . --import | Out-Null
& $GodotExe --headless --path . --script res://tests/run_tests.gd
Pop-Location

Write-Host "`nTout est pret !" -ForegroundColor Green
Write-Host "1. Ferme et rouvre ce terminal (pour le PATH)."
Write-Host "2. cd dans le dossier CREOS puis tape : claude"
Write-Host "3. Colle le message de docs\DEMARRAGE.md (section 'Premier message')."

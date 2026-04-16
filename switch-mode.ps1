<#
.SYNOPSIS
    Panel de control para MAMP: modo personal/laboral y version de PHP.

.DESCRIPTION
    - Reemplaza C:\MAMP\htdocs con un junction a D:\htdocs\personal o D:\htdocs\laboral.
    - Cambia la version de PHP renombrando versiones superiores con sufijo _X.
    - MAMP muestra las 2 mas altas visibles. El usuario selecciona en Preferences -> PHP.
    - Reinicia MAMP solo si cambia PHP.

.NOTES
    Requiere ejecutarse como Administrador.
#>

# -----------------------------
# Verificar permisos de Administrador
# -----------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Write-Host ""
    Write-Host "  [ERROR] Este script requiere permisos de Administrador." -ForegroundColor Red
    Write-Host ""
    exit 1
}

# -----------------------------
# Configuracion
# -----------------------------
$MampHtdocs    = "C:\MAMP\htdocs"
$MampHtdocsBak = "C:\MAMP\htdocs_original"
$PersonalPath  = "D:\htdocs\personal"
$LaboralPath   = "D:\htdocs\laboral"
$MampExe       = "C:\MAMP\MAMP.exe"
$PhpBaseDir    = "C:\MAMP\bin\php"
$HiddenSuffix  = "_X"

# =============================================================
#  FUNCIONES
# =============================================================

function Show-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  ==========================================" -ForegroundColor Cyan
    Write-Host "       MAMP Control Panel" -ForegroundColor Cyan
    Write-Host "  ==========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Get-CurrentMode {
    if (Test-Path $MampHtdocs) {
        $item = Get-Item $MampHtdocs -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            $target = cmd /c dir /AL (Split-Path $MampHtdocs -Parent) 2>$null |
                Select-String "htdocs" |
                Select-Object -First 1 |
                ForEach-Object { ($_ -split '\[|\]')[1] }
            if ($target -like "*personal*") { return "PERSONAL" }
            elseif ($target -like "*laboral*") { return "LABORAL" }
            return "JUNCTION -> $target"
        }
        return "CARPETA ORIGINAL"
    }
    return "NO EXISTE"
}

function Get-MampStatus {
    $httpd = Get-Process -Name "httpd" -ErrorAction SilentlyContinue
    $mysqld = Get-Process -Name "mysqld" -ErrorAction SilentlyContinue
    if ($httpd -and $mysqld) { return "CORRIENDO (Apache + MySQL)" }
    elseif ($httpd) { return "PARCIAL (solo Apache)" }
    elseif ($mysqld) { return "PARCIAL (solo MySQL)" }
    return "DETENIDO"
}

function Get-PhpVersions {
    $folders = Get-ChildItem -Path $PhpBaseDir -Directory | Where-Object { $_.Name -match "^php\d" }
    $versions = @()
    foreach ($folder in $folders) {
        $null = $folder.Name -match '^php([\d.]+)'
        $versionStr = $Matches[1]
        $cleanName = "php$versionStr"
        $isHidden  = $folder.Name -ne $cleanName

        $parts = $versionStr -split '\.'
        while ($parts.Count -lt 3) { $parts += "0" }
        $safeVersion = $parts[0..2] -join '.'

        $versions += [PSCustomObject]@{
            FolderName  = $folder.Name
            CleanName   = $cleanName
            VersionNum  = [version]$safeVersion
            IsHidden    = $isHidden
            FullPath    = $folder.FullName
        }
    }
    return $versions | Sort-Object VersionNum
}

function Get-ActivePhp {
    param($Versions)
    $visible = $Versions | Where-Object { -not $_.IsHidden } | Sort-Object VersionNum -Descending
    if ($visible) { return $visible[0].CleanName }
    return "desconocida"
}

function Stop-Mamp {
    Write-Host "  Deteniendo MAMP..." -ForegroundColor Yellow
    taskkill /IM MAMP.exe /F 2>$null | Out-Null
    Start-Sleep -Seconds 2
    taskkill /IM httpd.exe /F 2>$null | Out-Null
    taskkill /IM mysqld.exe /F 2>$null | Out-Null
    Start-Sleep -Seconds 2
    $timeout = 10
    $elapsed = 0
    while ($elapsed -lt $timeout) {
        $still = Get-Process -Name "httpd","mysqld","MAMP" -ErrorAction SilentlyContinue
        if (-not $still) { break }
        Start-Sleep -Seconds 1
        $elapsed++
    }
    Write-Host "  MAMP detenido." -ForegroundColor Green
}

function Start-Mamp {
    if (-not (Test-Path $MampExe)) {
        Write-Host "  [AVISO] No se encontro MAMP en: $MampExe" -ForegroundColor Yellow
        return
    }
    Write-Host "  Iniciando MAMP..." -ForegroundColor Yellow
    Start-Process -FilePath $MampExe
    $timeout = 20
    $elapsed = 0
    while ($elapsed -lt $timeout) {
        $httpd = Get-Process -Name "httpd" -ErrorAction SilentlyContinue
        if ($httpd) {
            Write-Host "  MAMP iniciado." -ForegroundColor Green
            return
        }
        Start-Sleep -Seconds 1
        $elapsed++
    }
    Write-Host "  MAMP iniciado (verificar si Apache levanto)." -ForegroundColor Yellow
}

function Initialize-Junction {
    if (Test-Path $MampHtdocs) {
        $item = Get-Item $MampHtdocs -Force
        if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            if (-not (Test-Path $MampHtdocsBak)) {
                Write-Host "  Respaldando htdocs original a htdocs_original..." -ForegroundColor Yellow
                Rename-Item -Path $MampHtdocs -NewName "htdocs_original" -Force
                Write-Host "  Backup creado: $MampHtdocsBak" -ForegroundColor Green
                Write-Host ""
            }
            else {
                Write-Host "  [ERROR] $MampHtdocsBak ya existe y htdocs no es junction." -ForegroundColor Red
                pause
                exit 1
            }
        }
    }
}

# =============================================================
#  PASO 1: ESTADO ACTUAL
# =============================================================

Show-Header

$currentMode = Get-CurrentMode
$mampStatus  = Get-MampStatus
$phpVersions = Get-PhpVersions
$currentPhp  = Get-ActivePhp -Versions $phpVersions

$mampColor = if ($mampStatus -like "CORRIENDO*") { "Green" } elseif ($mampStatus -eq "DETENIDO") { "Red" } else { "Yellow" }
$modeColor = if ($currentMode -like "NO *" -or $currentMode -like "CARPETA*") { "Yellow" } else { "White" }

Write-Host "  Estado MAMP:    $mampStatus" -ForegroundColor $mampColor
Write-Host "  Modo actual:    $currentMode" -ForegroundColor $modeColor
Write-Host "  PHP max visible:$currentPhp" -ForegroundColor White
Write-Host ""

# =============================================================
#  PASO 2: ELEGIR MODO
# =============================================================

Write-Host "  --- Modo de trabajo ---" -ForegroundColor Cyan
Write-Host "  [1] Personal"
Write-Host "  [2] Laboral"
Write-Host ""
$modeChoice = Read-Host "  Elige modo"

switch ($modeChoice) {
    "1" { $selectedMode = "personal"; $targetPath = $PersonalPath }
    "2" { $selectedMode = "laboral";  $targetPath = $LaboralPath }
    "0" { exit 0 }
    default {
        Write-Host "  Opcion no valida." -ForegroundColor Red
        Start-Sleep -Seconds 2
        exit 1
    }
}

if (-not (Test-Path $targetPath)) {
    Write-Host "  [ERROR] No existe: $targetPath" -ForegroundColor Red
    pause
    exit 1
}

Initialize-Junction

if (Test-Path $MampHtdocs) {
    $item = Get-Item $MampHtdocs -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        cmd /c rmdir "$MampHtdocs" 2>$null | Out-Null
    }
    else {
        Write-Host "  [ERROR] htdocs no es junction. Revisa manualmente." -ForegroundColor Red
        pause
        exit 1
    }
}

cmd /c mklink /J "$MampHtdocs" "$targetPath" 2>$null | Out-Null

if (-not (Test-Path $MampHtdocs)) {
    Write-Host "  [ERROR] No se pudo crear la junction." -ForegroundColor Red
    pause
    exit 1
}

Write-Host ""
Write-Host "  Modo: $selectedMode" -ForegroundColor Green
Write-Host "  htdocs -> $targetPath" -ForegroundColor Gray
Write-Host ""

# =============================================================
#  PASO 3: ELEGIR VERSION DE PHP
# =============================================================

Write-Host "  --- Version de PHP ---" -ForegroundColor Cyan
Write-Host ""

$seen = @{}
$uniqueVersions = @()
foreach ($v in $phpVersions) {
    if (-not $seen.ContainsKey($v.CleanName)) {
        $seen[$v.CleanName] = $true
        $uniqueVersions += $v
    }
}
$i = 1
$phpMenu = @{}
foreach ($v in $uniqueVersions) {
    $marker = if ($v.CleanName -eq $currentPhp) { " <-- activa" } else { "" }
    $hidden = if ($v.IsHidden) { " (oculta)" } else { "" }
    $color  = if ($v.CleanName -eq $currentPhp) { "Green" } else { "White" }
    Write-Host "  [$i] $($v.CleanName)$marker$hidden" -ForegroundColor $color
    $phpMenu[$i.ToString()] = $v
    $i++
}
Write-Host ""
Write-Host "  [0] Salir" -ForegroundColor Yellow
Write-Host ""
$phpChoice = Read-Host "  Elige version de PHP"

$phpChanged = $false

if ($phpChoice -eq "0") {
    Write-Host ""
    Write-Host "  Saliendo sin cambiar PHP." -ForegroundColor Gray
    Write-Host ""
    pause
    exit 0
}

if ($phpChoice -ne "S" -and $phpChoice -ne "s" -and $phpChoice -ne "") {

    if (-not $phpMenu.ContainsKey($phpChoice.Trim())) {
        Write-Host "  [ERROR] Opcion invalida." -ForegroundColor Red
        pause
        exit 1
    }

    $selectedPhp = $phpMenu[$phpChoice.Trim()]

    if ($selectedPhp.CleanName -eq $currentPhp) {
        Write-Host ""
        Write-Host "  PHP $($selectedPhp.CleanName) ya esta activa. Sin cambios." -ForegroundColor Green
    }
    else {
        $phpChanged = $true
        Write-Host ""
        Write-Host "  Activando: $($selectedPhp.CleanName)" -ForegroundColor Yellow
        Write-Host ""

        # Detener MAMP antes de renombrar
        $mampWasRunning = (Get-MampStatus) -ne "DETENIDO"
        if ($mampWasRunning) {
            Stop-Mamp
            Write-Host ""
        }

        # Renombrar carpetas:
        # - Superiores a la elegida: agregar _X
        # - Inferiores o igual: quitar _X si lo tienen
        foreach ($v in $phpVersions) {
            if ($v.VersionNum -gt $selectedPhp.VersionNum) {
                if (-not $v.IsHidden) {
                    $newName = "$($v.FolderName)$HiddenSuffix"
                    Rename-Item -Path $v.FullPath -NewName $newName -Force
                    Write-Host "    Ocultada: $($v.CleanName) -> $newName" -ForegroundColor DarkGray
                }
            }
            else {
                if ($v.IsHidden) {
                    Rename-Item -Path $v.FullPath -NewName $v.CleanName -Force
                    Write-Host "    Restaurada: $($v.CleanName)" -ForegroundColor Green
                }
            }
        }

        # Calcular las 2 versiones que MAMP vera
        $visibleAfter = $phpVersions | ForEach-Object {
            $isNowHidden = $_.VersionNum -gt $selectedPhp.VersionNum
            if (-not $isNowHidden) { $_ }
        } | Sort-Object VersionNum -Descending | Select-Object -First 2

        Write-Host ""
        Write-Host "  Carpetas listas." -ForegroundColor Green

        
    }
}
else {
    Write-Host "  PHP sin cambios." -ForegroundColor Gray
}

# =============================================================
#  PASO 4: ASEGURAR QUE MAMP ESTE CORRIENDO
# =============================================================

Write-Host ""
$mampStatus = Get-MampStatus

if ($mampStatus -like "CORRIENDO*") {
    Write-Host "  MAMP ya esta corriendo." -ForegroundColor Green
}
else {
    Start-Mamp
}

# Automatizar seleccion de PHP en MAMP via SendKeys
if ($phpChanged) {
    Write-Host ""
    Write-Host "  Configurando PHP en MAMP automaticamente..." -ForegroundColor Yellow
    Write-Host "  (No toques el teclado ni el mouse por unos segundos)" -ForegroundColor DarkGray
    Write-Host ""

    # Esperar a que MAMP este listo y en primer plano
    Start-Sleep -Seconds 3

    # Traer ventana de MAMP al frente
    $mampProc = Get-Process -Name "MAMP" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($mampProc) {
        Add-Type @"
            using System;
            using System.Runtime.InteropServices;
            public class Win32 {
                [DllImport("user32.dll")]
                public static extern bool SetForegroundWindow(IntPtr hWnd);
                [DllImport("user32.dll")]
                public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
            }
"@
        $hwnd = $mampProc.MainWindowHandle
        [Win32]::ShowWindow($hwnd, 9) | Out-Null   # SW_RESTORE
        [Win32]::SetForegroundWindow($hwnd) | Out-Null
        Start-Sleep -Seconds 1
    }

    $wshell = New-Object -ComObject WScript.Shell
    Start-Sleep -Milliseconds 500

    # Secuencia de teclas para navegar MAMP Preferences:
    # TAB          -> Foco en menu
    # ENTER x2     -> Abrir Preferences
    $wshell.SendKeys("{TAB}")
    Start-Sleep -Milliseconds 300
    $wshell.SendKeys("{ENTER}")
    Start-Sleep -Milliseconds 300
    $wshell.SendKeys("{ENTER}")
    Start-Sleep -Milliseconds 800

    # CTRL+TAB x3  -> Ir a pestana PHP
    $wshell.SendKeys("^{TAB}")
    Start-Sleep -Milliseconds 300
    $wshell.SendKeys("^{TAB}")
    Start-Sleep -Milliseconds 300
    $wshell.SendKeys("^{TAB}")
    Start-Sleep -Milliseconds 500

    # ABAJO x2     -> Seleccionar segunda version (la elegida)
    $wshell.SendKeys("{DOWN}")
    Start-Sleep -Milliseconds 300
    $wshell.SendKeys("{DOWN}")
    Start-Sleep -Milliseconds 300

    # TAB x2       -> Ir al boton OK
    $wshell.SendKeys("{TAB}")
    Start-Sleep -Milliseconds 300
    $wshell.SendKeys("{TAB}")
    Start-Sleep -Milliseconds 300

    # ENTER        -> Confirmar
    $wshell.SendKeys("{ENTER}")
    Start-Sleep -Milliseconds 500

    Write-Host "  PHP configurado automaticamente." -ForegroundColor Green

    # Esperar a que MAMP reinicie Apache
    Start-Sleep -Seconds 3

    # Minimizar ventana de MAMP
    $mampProc = Get-Process -Name "MAMP" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($mampProc) {
        $hwnd = $mampProc.MainWindowHandle
        [Win32]::ShowWindow($hwnd, 6) | Out-Null   # SW_MINIMIZE
        Write-Host "  MAMP minimizado." -ForegroundColor Gray
    }
}

# =============================================================
#  RESUMEN FINAL
# =============================================================

Write-Host ""
Write-Host "  ==========================================" -ForegroundColor Green
Write-Host "  Modo:   $selectedMode" -ForegroundColor Green
if ($phpChanged) {
    Write-Host "  PHP:    $($selectedPhp.CleanName)" -ForegroundColor Green
}
else {
    Write-Host "  PHP:    $currentPhp" -ForegroundColor Green
}
Write-Host "  URL:    http://localhost/" -ForegroundColor Green
Write-Host "  ==========================================" -ForegroundColor Green
Write-Host ""

pause

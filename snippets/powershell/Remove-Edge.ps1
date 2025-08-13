<# 
.SYNOPSIS
    Removes Microsoft Edge (Stable/Core) on Windows 11, hardens against reinstalls, 
    redirects microsoft-edge:// links to your default browser, and validates results.

.DESCRIPTION
    - Safe-by-default (does NOT remove WebView2/Widgets/Gaming Services unless asked)
    - Skips non-removable DevTools Client package
    - PS 5.1–compatible
    - Cleans EdgeUpdate components regardless of options
    - Creates/repairs protocol-redirect shim via IFEO + OpenWebSearch.cmd
    - Logs to transcript + a rolling plain-text log
    - Runs post-action validation and prints results to terminal and log

.PARAMETER RemoveWebView
    Remove Edge WebView2 runtime (may break apps that embed it).

.PARAMETER RemoveWidgets
    Remove Windows WebExperience (Widgets).

.PARAMETER RemoveXSocial
    Remove Gaming Services "social" bits (Game Bar still works).

.PARAMETER MultiUserScrub
    Also scrub HKU S-1-5-21* protocol keys (multi-user machines). Default: off.

.PARAMETER EnableRestorePoint
    Attempts a System Restore point before changes (if enabled).

.PARAMETER FullSend
    Shorthand to enable: -RemoveWebView -RemoveWidgets -RemoveXSocial.

.PARAMETER LogPath
    Optional explicit log path (defaults to %TEMP%\EdgeRemoval_yyyyMMdd_HHmmss.log).

.PARAMETER ValidateEdgeProtocol
    Launches a test microsoft-edge:// URL to assert redirect works.

.EXAMPLE
    .\Remove-Edge.ps1

.EXAMPLE
    .\Remove-Edge.ps1 -FullSend -ValidateEdgeProtocol

.NOTES
    Author: PowerShell Community
    Prerequisites: PowerShell V5.1 or higher, Administrative privileges
    Requires: Windows 11 (tested on build 22000+)
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$RemoveWebView,
    [switch]$RemoveWidgets,
    [switch]$RemoveXSocial,
    [switch]$MultiUserScrub,
    [switch]$EnableRestorePoint,
    [switch]$FullSend,
    [string]$LogPath,
    [switch]$ValidateEdgeProtocol
)

# ----------------------- Setup & Logging -----------------------

$ErrorActionPreference = 'SilentlyContinue'
$PSDefaultParameterValues['*:ErrorAction'] = 'SilentlyContinue'

# Expand FullSend into individual flags
if ($FullSend) {
    $RemoveWebView = $true
    $RemoveWidgets = $true
    $RemoveXSocial = $true
}

# Timestamped log file
if (-not $LogPath) {
    $LogPath = Join-Path $env:TEMP ("EdgeRemoval_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))
}

# Start transcript (best-effort)
try { 
    Start-Transcript -Path $LogPath -Force | Out-Null 
} catch {
    Write-Warning "Could not start transcript logging"
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message, 
        [ValidateSet('INFO','WARN','ERROR')]
        [string]$Level = 'INFO'
    )
    
    $TimeStamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $LogLine = "[$TimeStamp][$Level] $Message"
    Write-Host $LogLine
    try { 
        Add-Content -Path $LogPath -Value $LogLine 
    } catch {
        Write-Warning "Could not write to log file: $LogPath"
    }
}

Write-Host ("="*78)
Write-Log "Starting Edge removal routine (PSVersion: $($PSVersionTable.PSVersion))"

# ----------------------- Global Variables -----------------------

$Is64Bit = [Environment]::Is64BitOperatingSystem
$OSBuild = [Environment]::OSVersion.Version.Build
$ProgramsPath = ($env:ProgramFiles, ${env:ProgramFiles(x86)})[$Is64Bit]
$SoftwareKey = ('SOFTWARE', 'SOFTWARE\WOW6432Node')[$Is64Bit]
$ImageFileExecutionOptions = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
$AllRegistryHives = @('HKCU:\SOFTWARE','HKLM:\SOFTWARE','HKCU:\SOFTWARE\Policies','HKLM:\SOFTWARE\Policies')
if ($Is64Bit) { 
    $AllRegistryHives += "HKCU:\$SoftwareKey","HKLM:\$SoftwareKey","HKCU:\$SoftwareKey\Policies","HKLM:\$SoftwareKey\Policies" 
}

$EdgeUID = '{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}'
$WebViewUID = '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'
$UpdateUID = '{F3C4FE00-EFD5-403B-9569-398A20F1BA4A}'

$RemoveAppxPackages = @('MicrosoftEdge')  # Base packages
$RemoveWin32Apps = @('Microsoft Edge','Microsoft Edge Update')
# Skip list (non-removable or benign)
$SkipPatterns = @('MicrosoftEdgeDevToolsClient','DevToolsClient')

if ($RemoveWebView) { 
    $RemoveAppxPackages += 'Win32WebViewHost'
    $RemoveWin32Apps += 'Microsoft EdgeWebView' 
}
if ($RemoveWidgets) { 
    $RemoveAppxPackages += 'WebExperience' 
}
if ($RemoveXSocial) { 
    $RemoveAppxPackages += 'GamingServices' 
}

$ScriptsDirectory = "$env:SystemDrive\Scripts"
$null = New-Item -ItemType Directory -Path $ScriptsDirectory -Force

# ----------------------- Helper Functions -----------------------
function Set-RegistryProperty {
    param([string]$Path, [string]$Name, [object]$Value, [string]$Type = 'String')
    if (Test-Path $Path) { 
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
    } else { 
        New-Item -Path $Path -Force | Out-Null
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
    }
}

function Remove-RegistryProperty {
    param([string]$Path, [string]$Name)
    if (Test-Path $Path) { 
        Remove-ItemProperty -Path $Path -Name $Name -Force 
    }
}

function New-RegistryItem {
    param([string]$Path)
    if (-not (Test-Path $Path)) { 
        New-Item -Path $Path -Force 
    }
}

function Remove-RegistryItem {
    param([string]$Path)
    if (Test-Path $Path) { 
        Remove-Item -Path $Path -Recurse -Force 
    }
}

# ----------------------- Optional Restore Point -----------------------
if ($EnableRestorePoint) {
    Write-Log "Attempting to create a System Restore Point..."
    try { 
        Checkpoint-Computer -Description "Pre-EdgeRemoval" -RestorePointType "MODIFY_SETTINGS" | Out-Null 
        Write-Log "System Restore Point created successfully"
    } catch { 
        Write-Log "Restore point failed or disabled." "WARN" 
    }
}

# ----------------------- Elevation-related Privileges -----------------------
try {
    $ProcessType = [uri].module.gettype('System.Diagnostics.Process')."GetM`ethods"(42) | Where-Object {$_.Name -eq 'SetPrivilege'}
    $Privileges = @('SeSecurityPrivilege','SeTakeOwnershipPrivilege','SeBackupPrivilege','SeRestorePrivilege')
    foreach ($Privilege in $Privileges) { 
        $ProcessType.Invoke($null, @("$Privilege",2)) 
    }
    Write-Log "Enabled extra process privileges."
} catch { 
    Write-Log "Could not enable extra privileges (continuing)." "WARN" 
}

# ----------------------- Prepare EdgeUpdate Keys -----------------------
function Initialize-EdgeUpdate {
    [CmdletBinding()]
    param(
        [string]$CdpName = 'msedgeupdate', 
        [string]$UID = $UpdateUID
    )
    
    foreach ($RegistryHive in $AllRegistryHives) {
        Remove-RegistryProperty "$RegistryHive\Microsoft\EdgeUpdate" 'DoNotUpdateToEdgeWithChromium'
        Remove-RegistryProperty "$RegistryHive\Microsoft\EdgeUpdate" 'UpdaterExperimentationAndConfigurationServiceControl'
        Remove-RegistryProperty "$RegistryHive\Microsoft\EdgeUpdate" 'InstallDefault'
        Remove-RegistryProperty "$RegistryHive\Microsoft\EdgeUpdate" "Install${UID}"
        Remove-RegistryProperty "$RegistryHive\Microsoft\EdgeUpdate" "EdgePreview${UID}"
        Remove-RegistryProperty "$RegistryHive\Microsoft\EdgeUpdate" "Update${UID}"
        Remove-RegistryProperty "$RegistryHive\Microsoft\EdgeUpdate\ClientState\*" 'experiment_control_labels'
        Remove-RegistryItem "$RegistryHive\Microsoft\EdgeUpdate\Clients\${UID}\Commands"
        Remove-RegistryProperty "$RegistryHive\Microsoft\EdgeUpdateDev\CdpNames" "$CdpName-*"
        Set-RegistryProperty "$RegistryHive\Microsoft\EdgeUpdateDev" 'CanContinueWithMissingUpdate' 1 -Type 'Dword'
        Set-RegistryProperty "$RegistryHive\Microsoft\EdgeUpdateDev" 'AllowUninstall' 1 -Type 'Dword'
    }
}

function Initialize-Edge {
    Initialize-EdgeUpdate -CdpName 'msedge' -UID $EdgeUID
    Initialize-EdgeUpdate -CdpName 'msedgeupdate' -UID $UpdateUID
    
    $EdgePath = "$ProgramsPath\Microsoft\Edge\Application\msedge.exe"
    Remove-RegistryItem "$ImageFileExecutionOptions\msedge.exe"
    Remove-RegistryItem "$ImageFileExecutionOptions\ie_to_edge_stub.exe"
    
    if ($MultiUserScrub) { 
        Remove-RegistryItem 'Registry::HKEY_Users\S-1-5-21*\Software\Classes\microsoft-edge' 
    }
    
    Set-RegistryProperty 'HKLM:\SOFTWARE\Classes\microsoft-edge\shell\open\command' '(Default)' "`"$EdgePath`" --single-argument %%1"
    
    if ($MultiUserScrub) { 
        Remove-RegistryItem 'Registry::HKEY_Users\S-1-5-21*\Software\Classes\MSEdgeHTM' 
    }
    
    Set-RegistryProperty 'HKLM:\SOFTWARE\Classes\MSEdgeHTM\shell\open\command' '(Default)' "`"$EdgePath`" --single-argument %%1"
    Write-Log "Prepared Edge/Updater registry for uninstall and sane handlers."
}

function Initialize-WebView {
    Initialize-EdgeUpdate -CdpName 'msedgewebview' -UID $WebViewUID
    Initialize-EdgeUpdate -CdpName 'msedgeupdate' -UID $UpdateUID
    
    $Config = @{
        Register = $true
        ForceApplicationShutdown = $true
        ForceUpdateFromAnyVersion = $true
        DisableDevelopmentMode = $true
    }
    
    Get-ChildItem "$env:SystemRoot\SystemApps\Microsoft.Win32WebViewHost*\AppxManifest.xml" -Recurse | Add-AppxPackage @Config
    Get-ChildItem "$env:ProgramFiles\WindowsApps\MicrosoftWindows.Client.WebExperience*\AppxManifest.xml" -Recurse | Add-AppxPackage @Config
    
    if (-not (Get-Process -Name 'explorer')) { 
        Start-Process explorer 
    }
    Write-Log "Prepared WebView/Widgets registration (recovery)."
}

# ----------------------- Kill Likely Blockers -----------------------
$ProcessesToKill = @('Widgets','widgetservice','msedgewebview2','MicrosoftEdge*','chredge','msedge','edge','msteams','msfamily','WebViewHost','Clipchamp')
foreach ($Process in $ProcessesToKill) { 
    Stop-Process -Name $Process -Force -ErrorAction SilentlyContinue
}

# ----------------------- Unblock Win32 Uninstall -----------------------
foreach ($AppName in $RemoveWin32Apps) {
    foreach ($RegistryHive in $AllRegistryHives) {
        $UninstallKey = "$RegistryHive\Microsoft\Windows\CurrentVersion\Uninstall\$AppName"
        if (-not (Test-Path $UninstallKey)) { 
            continue 
        }
        
        $BlockingProperties = @('NoRemove','NoModify','NoRepair')
        foreach ($Property in $BlockingProperties) { 
            Remove-RegistryProperty $UninstallKey $Property 
        }
        
        $ForceProperties = @('ForceRemove','Delete')
        foreach ($Property in $ForceProperties) { 
            Set-RegistryProperty $UninstallKey $Property 1 -Type 'Dword'
        }
    }
}
Initialize-Edge

# ----------------------- Find Installers & Stubs -----------------------
$EdgeInstallers = @()
$BrowserHelperObjects = @()
$EdgeUpdates = @()

$SearchRoots = @('LocalApplicationData','ProgramFilesX86','ProgramFiles')
foreach ($Root in $SearchRoots) {
    $Folder = [Environment]::GetFolderPath($Root)
    if ($Folder) {
        $BrowserHelperObjects += Get-ChildItem "$Folder\Microsoft\Edge*\ie_to_edge_stub.exe" -Recurse
        if ($RemoveWebView) { 
            $EdgeInstallers += Get-ChildItem "$Folder\Microsoft\Edge*\setup.exe" -Recurse | Where-Object { $_ -like '*EdgeWebView*' } 
        }
        $EdgeInstallers += Get-ChildItem "$Folder\Microsoft\Edge*\setup.exe" -Recurse | Where-Object { $_ -notlike '*EdgeWebView*' }
        $EdgeUpdates += Get-ChildItem "$Folder\Microsoft\EdgeUpdate\*.*.*.*\MicrosoftEdgeUpdate.exe" -Recurse
    }
}

# Export stub for OpenWebSearch
$StubCopied = $false
foreach ($Stub in $BrowserHelperObjects) {
    if (Test-Path $Stub) {
        for ($Attempt = 0; $Attempt -lt 3 -and -not $StubCopied; $Attempt++) {
            try { 
                Copy-Item $Stub "$ScriptsDirectory\ie_to_edge_stub.exe" -Force -ErrorAction Stop
                $StubCopied = $true 
            } catch { 
                Start-Sleep -Milliseconds 300 
            }
        }
    }
}

if ($StubCopied) { 
    Write-Log "Copied ie_to_edge_stub.exe to $ScriptsDirectory" 
} else { 
    Write-Log "Could not copy ie_to_edge_stub.exe (will still attempt redirect setup)." "WARN" 
}

# ----------------------- AppX Removal (with unblock trick) -----------------------
$ProvisionedPackages = Get-AppxProvisionedPackage -Online
$AppxPackages = Get-AppxPackage -AllUsers
$EndOfLifePackages = @()
$AppxStore = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore'
$UserSIDs = @('S-1-5-18')

if (Test-Path $AppxStore -and $MultiUserScrub) {
    $UserSIDs += (Get-ChildItem $AppxStore | Where-Object { $_ -like '*S-1-5-21*' }).PSChildName
}

# Stop explorer right before removal
Stop-Process -Name explorer -ErrorAction SilentlyContinue
if (Get-Process -Name explorer) { 
    & taskkill /im explorer.exe /f 2>&1 | Out-Null 
}

foreach ($PackageChoice in $RemoveAppxPackages) {
    if ([string]::IsNullOrWhiteSpace($PackageChoice)) { 
        continue 
    }

    # Handle provisioned packages
    foreach ($Appx in ($ProvisionedPackages | Where-Object { $_.PackageName -like "*$PackageChoice*" })) {
        if ($SkipPatterns | Where-Object { $Appx.PackageName -like "*$_*" }) { 
            continue 
        }
        
        $PackageName = $Appx.PackageName
        $PackageFamilyName = ($AppxPackages | Where-Object { $_.Name -eq $Appx.DisplayName }).PackageFamilyName
        
        New-RegistryItem "$AppxStore\Deprovisioned\$PackageFamilyName"
        foreach ($SID in $UserSIDs) { 
            New-RegistryItem "$AppxStore\EndOfLife\$SID\$PackageName"
            $EndOfLifePackages += $PackageName 
        }
        
        & dism /online /set-nonremovableapppolicy /packagefamily:$PackageFamilyName /nonremovable:0 *> $null
        Remove-AppxProvisionedPackage -PackageName $PackageName -Online -AllUsers *> $null
        Write-Log "Deprovisioned $PackageName"
    }

    # Handle installed packages
    foreach ($Appx in ($AppxPackages | Where-Object { $_.PackageFullName -like "*$PackageChoice*" })) {
        if ($SkipPatterns | Where-Object { $Appx.PackageFullName -like "*$_*" }) { 
            continue 
        }
        
        $PackageFullName = $Appx.PackageFullName
        $PackageFamilyName = $Appx.PackageFamilyName
        
        New-RegistryItem "$AppxStore\Deprovisioned\$PackageFamilyName"
        foreach ($SID in $UserSIDs) { 
            New-RegistryItem "$AppxStore\EndOfLife\$SID\$PackageFullName"
            $EndOfLifePackages += $PackageFullName 
        }
        
        & dism /online /set-nonremovableapppolicy /packagefamily:$PackageFamilyName /nonremovable:0 *> $null
        Remove-AppxPackage -Package $PackageFullName -AllUsers *> $null
        Write-Log "Removed AppX $PackageFullName"
    }
}

# ----------------------- Run Setup.exe Uninstalls (PS 5.1-safe) -----------------------
foreach ($Setup in $EdgeInstallers) {
    if (-not (Test-Path $Setup)) { 
        continue 
    }
    
    $IsUserLevel = ($Setup.FullName -like '*\AppData\Local\*')
    $SystemLevel = if ($IsUserLevel) { '--user-level' } else { '--system-level' }
    $Target = if ($Setup.FullName -like '*EdgeWebView*') { '--msedgewebview' } else { '--msedge' }
    $RemovalArgs = "--uninstall $Target $SystemLevel --verbose-logging --force-uninstall"
    
    Write-Log "Running: $($Setup.FullName) $RemovalArgs"
    try {
        Start-Process -FilePath $Setup.FullName -ArgumentList $RemovalArgs -Wait
    } catch { 
        Write-Log "Failed to run setup: $($Setup.FullName)" "WARN" 
    }
    
    do { 
        Start-Sleep 3 
    } while ((Get-Process -Name 'setup','MicrosoftEdge*').Path -like '*\Microsoft\Edge*')
}

# ----------------------- MSI Cleanup -----------------------
Get-ItemProperty 'HKLM:\SOFTWARE\Classes\Installer\Products\*' 'ProductName' | Where-Object { $_.ProductName -like '*Microsoft Edge*' } | ForEach-Object {
    $ProductCode = ($_.PSChildName -split '(.{8})(.{4})(.{4})(.{4})' -join '-').Trim('-')
    $SortOrder = @(7,6,5,4,3,2,1,0,8,12,11,10,9,13,17,16,15,14,18,20,19,22,21,23,25,24,27,26,29,28,31,30,33,32,35,34)
    $MSICode = '{' + (-join ($SortOrder | ForEach-Object { $ProductCode[$_] })) + '}'
    
    Write-Log "MSI remove: $MSICode"
    Start-Process msiexec.exe -ArgumentList "/X$MSICode /qn" -Wait
    Remove-RegistryItem $_.PSPath
    
    foreach ($RegistryHive in $AllRegistryHives) { 
        Remove-RegistryItem "$RegistryHive\Microsoft\Windows\CurrentVersion\Uninstall\$MSICode" 
    }
}

# ----------------------- EdgeUpdate Cleanup (always) -----------------------
foreach ($RegistryHive in $AllRegistryHives) { 
    Remove-RegistryItem "$RegistryHive\Microsoft\EdgeUpdate" 
}

foreach ($Update in $EdgeUpdates) {
    if (Test-Path $Update) { 
        Write-Log "$Update /unregsvc"
        Start-Process -FilePath $Update -ArgumentList '/unregsvc' -Wait 
    }
    
    do { 
        Start-Sleep 3 
    } while ((Get-Process -Name 'setup','MicrosoftEdge*').Path -like '*\Microsoft\Edge*')
    
    if (Test-Path $Update) { 
        Write-Log "$Update /uninstall"
        Start-Process -FilePath $Update -ArgumentList '/uninstall' -Wait 
    }
    
    do { 
        Start-Sleep 3 
    } while ((Get-Process -Name 'setup','MicrosoftEdge*').Path -like '*\Microsoft\Edge*')
}

Unregister-ScheduledTask -TaskName MicrosoftEdgeUpdate* -Confirm:$false

# Extra hardening: remove services if present
$EdgeServices = @('edgeupdate','edgeupdatem')
foreach ($Service in $EdgeServices) {
    try { 
        Stop-Service $Service -Force 
    } catch {}
    try { 
        sc.exe delete $Service | Out-Null 
    } catch {}
}

# ----------------------- Pin Cleanup & Explorer -----------------------
$AppDataPath = [Environment]::GetFolderPath('ApplicationData')
Remove-RegistryItem "$AppDataPath\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Tombstones\Microsoft Edge.lnk"
Remove-RegistryItem "$AppDataPath\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk"

if (-not (Get-Process -Name 'explorer')) { 
    Start-Process explorer 
}

# ----------------------- Undo EOL Unblock -----------------------
$AppxStore = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore'
foreach ($SID in $UserSIDs) { 
    foreach ($Package in $EndOfLifePackages) { 
        Remove-RegistryItem "$AppxStore\EndOfLife\$SID\$Package" 
    } 
}

# ----------------------- Policy Hardening -----------------------
$UIDs = @($EdgeUID)
$CdpNames = @('msedge')

if ($RemoveWebView) { 
    $UIDs += $WebViewUID
    $CdpNames += 'msedgewebview' 
}

foreach ($RegistryHive in $AllRegistryHives) {
    Set-RegistryProperty "$RegistryHive\Microsoft\EdgeUpdate" 'DoNotUpdateToEdgeWithChromium' 1 -Type 'Dword'
    Set-RegistryProperty "$RegistryHive\Microsoft\EdgeUpdate" 'UpdaterExperimentationAndConfigurationServiceControl' 0 -Type 'Dword'
    Set-RegistryProperty "$RegistryHive\Microsoft\EdgeUpdate" 'InstallDefault' 0 -Type 'Dword'
    
    foreach ($UID in $UIDs) {
        Set-RegistryProperty "$RegistryHive\Microsoft\EdgeUpdate" "Install${UID}" 0 -Type 'Dword'
        Set-RegistryProperty "$RegistryHive\Microsoft\EdgeUpdate" "EdgePreview${UID}" 0 -Type 'Dword'
        Set-RegistryProperty "$RegistryHive\Microsoft\EdgeUpdate" "Update${UID}" 2 -Type 'Dword'
        
        $Triggers = @('on-os-upgrade','on-logon','on-logon-autolaunch','on-logon-startup-boost')
        foreach ($Trigger in $Triggers) {
            Set-RegistryProperty "$RegistryHive\Microsoft\EdgeUpdate\Clients\${UID}\Commands\$Trigger" 'AutoRunOnLogon' 0 -Type 'Dword'
            Set-RegistryProperty "$RegistryHive\Microsoft\EdgeUpdate\Clients\${UID}\Commands\$Trigger" 'AutoRunOnOSUpgrade' 0 -Type 'Dword'
            Set-RegistryProperty "$RegistryHive\Microsoft\EdgeUpdate\Clients\${UID}\Commands\$Trigger" 'Enabled' 0 -Type 'Dword'
        }
    }
    
    Set-RegistryProperty "$RegistryHive\Microsoft\MicrosoftEdge\Main" 'AllowPrelaunch' 0 -Type 'Dword'
    Set-RegistryProperty "$RegistryHive\Microsoft\MicrosoftEdge\TabPreloader" 'AllowTabPreloading' 0 -Type 'Dword'
    
    foreach ($Cdp in $CdpNames) { 
        foreach ($Arch in @('x64','x86')) { 
            foreach ($Zdp in @('','-zdp')) {
                Set-RegistryProperty "$RegistryHive\Microsoft\EdgeUpdateDev\CdpNames" "$Cdp-stable-win-$Arch$Zdp" "$Cdp-stable-win-arm64$Zdp"
            }
        } 
    }
}

# ----------------------- Protocol Redirect: OpenWebSearch -----------------------
$OpenWebSearchScript = @"
@title OpenWebSearch Redux & echo off & set ?= open start menu web search, widgets links or help in your chosen browser - by AveYo
for /f %%E in ('"prompt $E$S& for %%e in (1) do rem"') do echo;%%E[2t 2>nul
call :reg_var "HKCU\SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice" ProgID ProgID
if /i "%ProgID%" equ "MSEdgeHTM" echo;Default browser is set to Edge! Change it or remove OpenWebSearch script. & pause & exit /b
call :reg_var "HKCR\%ProgID%\shell\open\command" "" Browser
set Choice=& for %%. in (%Browser%) do if not defined Choice set "Choice=%%~."
call :reg_var "HKCR\MSEdgeMHT\shell\open\command" "" FallBack
set "Edge=" & for %%. in (%FallBack%) do if not defined Edge set "Edge=%%~."
set "URI=" & set "URL=" & set "NOOP=" & set "PassTrough=%Edge:msedge=edge%"
set "CLI=%CMDCMDLINE:"=``% "
if defined CLI set "CLI=%CLI:*ie_to_edge_stub.exe`` =%"
if defined CLI set "CLI=%CLI:*ie_to_edge_stub.exe =%"
if defined CLI set "CLI=%CLI:*msedge.exe`` =%"
if defined CLI set "CLI=%CLI:*msedge.exe =%"
set "FIX=%CLI:~-1%"
if defined CLI if "%FIX%"==" " set "CLI=%CLI:~0,-1%"
if defined CLI set "RED=%CLI:microsoft-edge=%"
if defined CLI set "URL=%CLI:http=%"
if defined CLI set "ARG=%CLI:``="%"
if "%CLI%" equ "%RED%" (set NOOP=1) else if "%CLI%" equ "%URL%" (set NOOP=1)
if defined NOOP if not exist "%PassTrough%" echo;@mklink /h "%PassTrough%" "%Edge%" >"%Temp%\OpenWebSearchRepair.cmd"
if defined NOOP if not exist "%PassTrough%" schtasks /run /tn OpenWebSearchRepair 2>nul >nul
if defined NOOP if not exist "%PassTrough%" timeout /t 3 >nul
if defined NOOP if exist "%PassTrough%" start "" "%PassTrough%" %ARG%
if defined NOOP exit /b
set "URL=%CLI:*microsoft-edge=%"
set "URL=http%URL:*http=%"
set "FIX=%URL:~-2%"
if defined URL if "%FIX%"=="``" set "URL=%URL:~0,-2%"
call :dec_url
start "" "%Choice%" "%URL%"
exit

:reg_var [USAGE] call :reg_var "HKCU\Volatile Environment" value-or-"" variable [extra options]
set {var}=& set {reg}=reg query "%~1" /v %2 /z /se "," /f /e& if %2=="" set {reg}=reg query "%~1" /ve /z /se "," /f /e
for /f "skip=2 tokens=* delims=" %%V in ('%{reg}% %4 %5 %6 %7 %8 %9 2^>nul') do if not defined {var} set "{var}=%%V"
if not defined {var} (set {reg}=& set "%~3="& exit /b) else if %2=="" set "{var}=%{var}:*)    =%"
if not defined {var} (set {reg}=& set "%~3="& exit /b) else set {reg}=& set "%~3=%{var}:*)    =%"& set {var}=& exit /b

:dec_url
set ".=%URL:!=}%"&setlocal enabledelayedexpansion
set ".=!.:%%={!" &set ".=!.:{3A=:!" &set ".=!.:{2F=/!" &set ".=!.:{3F=?!" &set ".=!.:{23=#!" &set ".=!.:{5B=[!" &set ".=!.:{5D=]!"
set ".=!.:{40=@!"&set ".=!.:{21=}!" &set ".=!.:{24=$!" &set ".=!.:{26=&!" &set ".=!.:{27='!" &set ".=!.:{28=(!" &set ".=!.:{29=)!"
set ".=!.:{2A=*!"&set ".=!.:{2B=+!" &set ".=!.:{2C=,!" &set ".=!.:{3B=;!" &set ".=!.:{3D==!" &set ".=!.:{25=%%!"&set ".=!.:{20= !"
set ".=!.:{=%%!" & if "!,!" neq "!.!" endlocal& set "URL=%.:}=!%" & call :dec_url
endlocal& set "URL=%.:}=!%" & exit /b
"@

[io.file]::WriteAllText("$ScriptsDirectory\OpenWebSearch.cmd", $OpenWebSearchScript)

# Register protocol handlers to point at the stub
New-RegistryItem "HKLM:\SOFTWARE\Classes\microsoft-edge\shell\open\command"
Set-RegistryProperty "HKLM:\SOFTWARE\Classes\microsoft-edge" '(Default)' 'URL:microsoft-edge'
Set-RegistryProperty "HKLM:\SOFTWARE\Classes\microsoft-edge" 'URL Protocol' ''
Set-RegistryProperty "HKLM:\SOFTWARE\Classes\microsoft-edge" 'NoOpenWith' ''
Set-RegistryProperty "HKLM:\SOFTWARE\Classes\microsoft-edge\shell\open\command" '(Default)' "`"$ScriptsDirectory\ie_to_edge_stub.exe`" %1"

New-RegistryItem "HKLM:\SOFTWARE\Classes\MSEdgeHTM\shell\open\command"
Set-RegistryProperty "HKLM:\SOFTWARE\Classes\MSEdgeHTM" 'NoOpenWith' ''
Set-RegistryProperty "HKLM:\SOFTWARE\Classes\MSEdgeHTM\shell\open\command" '(Default)' "`"$ScriptsDirectory\ie_to_edge_stub.exe`" %1"

# IFEO debugger hooks (UseFilter if supported)
$UseFilter = ($OSBuild -ge 25179)
if ($UseFilter) {
    New-RegistryItem "$ImageFileExecutionOptions\ie_to_edge_stub.exe\0"
    Set-RegistryProperty "$ImageFileExecutionOptions\ie_to_edge_stub.exe" 'UseFilter' 1 -Type 'Dword'
    Set-RegistryProperty "$ImageFileExecutionOptions\ie_to_edge_stub.exe\0" 'FilterFullPath' "$ScriptsDirectory\ie_to_edge_stub.exe"
    Set-RegistryProperty "$ImageFileExecutionOptions\ie_to_edge_stub.exe\0" 'Debugger' "$env:systemroot\system32\conhost.exe --width 1 --height 1 $ScriptsDirectory\OpenWebSearch.cmd"

    $EdgeApplicationPath = ($env:ProgramFiles,${env:ProgramFiles(x86)})[[Environment]::Is64BitOperatingSystem] + '\Microsoft\Edge\Application'
    New-RegistryItem "$ImageFileExecutionOptions\msedge.exe\0"
    Set-RegistryProperty "$ImageFileExecutionOptions\msedge.exe" 'UseFilter' 1 -Type 'Dword'
    Set-RegistryProperty "$ImageFileExecutionOptions\msedge.exe\0" 'FilterFullPath' "$EdgeApplicationPath\msedge.exe"
    Set-RegistryProperty "$ImageFileExecutionOptions\msedge.exe\0" 'Debugger' "$env:systemroot\system32\conhost.exe --width 1 --height 1 $ScriptsDirectory\OpenWebSearch.cmd"
} else {
    Set-RegistryProperty "$ImageFileExecutionOptions\ie_to_edge_stub.exe" 'Debugger' "$env:systemroot\system32\conhost.exe --headless $ScriptsDirectory\OpenWebSearch.cmd"
    Set-RegistryProperty "$ImageFileExecutionOptions\msedge.exe" 'Debugger' "$env:systemroot\system32\conhost.exe --headless $ScriptsDirectory\OpenWebSearch.cmd"
}

# Scheduled task to repair stub hardlink on demand
$TaskAction = New-ScheduledTaskAction -Execute '%Temp%\OpenWebSearchRepair.cmd'
$TaskTrigger1 = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2)
$TaskTrigger2 = New-ScheduledTaskTrigger -AtLogOn
$TaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries

try {
    Register-ScheduledTask -TaskName 'OpenWebSearchRepair' -Action $TaskAction -Trigger @($TaskTrigger1,$TaskTrigger2) -Settings $TaskSettings -RunLevel Highest -Force | Out-Null
    Write-Log "Registered OpenWebSearchRepair scheduled task."
} catch { 
    Write-Log "Register-ScheduledTask failed: $($_.Exception.Message)" "WARN" 
}

# ----------------------- Validation -----------------------
Write-Host ("-"*78)
Write-Log "VALIDATION — starting"

$EdgeBinaryPaths = @(
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe"
)

$BinaryCheck = $EdgeBinaryPaths | ForEach-Object { $_, (Test-Path $_) } | ForEach-Object {
    if ($_ -is [string]) { 
        $script:LastPath = $_ 
        return 
    }
    $State = if ($_){'PRESENT'} else {'MISSING'}
    $Message = "Binary: $script:LastPath => $State"
    Write-Log $Message
}

# AppX remaining (we expect possibly DevToolsClient)
$RemainingAppx = Get-AppxPackage -AllUsers *MicrosoftEdge* | Select-Object Name, PackageFullName
if ($RemainingAppx) {
    Write-Log "Remaining Edge-related AppX packages:"
    $RemainingAppx | ForEach-Object { 
        Write-Log ("  {0}" -f $_.PackageFullName) 
    }
} else {
    Write-Log "No Edge-related AppX packages remain."
}

# Protocol command values
try {
    $MicrosoftEdgeCommand = (Get-ItemProperty 'HKLM:\SOFTWARE\Classes\microsoft-edge\shell\open\command').'(''default'')'
} catch { 
    $MicrosoftEdgeCommand = (Get-ItemProperty 'HKLM:\SOFTWARE\Classes\microsoft-edge\shell\open\command').'Default' 
}

try {
    $MSEdgeHTMCommand = (Get-ItemProperty 'HKLM:\SOFTWARE\Classes\MSEdgeHTM\shell\open\command').'(''default'')'
} catch { 
    $MSEdgeHTMCommand = (Get-ItemProperty 'HKLM:\SOFTWARE\Classes\MSEdgeHTM\shell\open\command').'Default' 
}

Write-Log "microsoft-edge handler => $MicrosoftEdgeCommand"
Write-Log "MSEdgeHTM handler      => $MSEdgeHTMCommand"

# IFEO keys presence
$MsEdgeIFEO = Get-Item "$ImageFileExecutionOptions\msedge.exe" -ErrorAction SilentlyContinue
$StubIFEO = Get-Item "$ImageFileExecutionOptions\ie_to_edge_stub.exe" -ErrorAction SilentlyContinue
Write-Log ("IFEO msedge.exe key    => " + ($(if ($MsEdgeIFEO) {'Present'} else {'Missing'})))
Write-Log ("IFEO ie_to_edge_stub   => " + ($(if ($StubIFEO) {'Present'} else {'Missing'})))

# Test protocol (optional)
if ($ValidateEdgeProtocol) {
    Write-Log "Launching microsoft-edge:// protocol test..."
    try { 
        Start-Process "microsoft-edge:https://example.com" 
    } catch {}
}

# Scheduled task present?
try {
    $ScheduledTask = Get-ScheduledTask -TaskName OpenWebSearchRepair
    Write-Log "Scheduled Task found: $($ScheduledTask.TaskName)."
} catch { 
    Write-Log "Scheduled Task 'OpenWebSearchRepair' not found." "WARN" 
}

Write-Log "VALIDATION — complete"
Write-Host ("="*78)

# ----------------------- Finish -----------------------
Write-Host "`nEDGE REMOVAL COMPLETE. Log: $LogPath"
try { 
    Stop-Transcript | Out-Null 
} catch {}

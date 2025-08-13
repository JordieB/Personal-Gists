<#
.SYNOPSIS
    Multi-phase Bluetooth device removal script with comprehensive logging and user confirmations.

.DESCRIPTION
    Removes stubborn Bluetooth devices using multiple removal methods including WMI/CIM,
    PowerShell PnP commands, DevCon utility, and registry cleanup. Designed specifically
    for removing problematic Bluetooth devices that persist after standard removal attempts.
    
    The script operates in phases:
    1. WMI/CIM device removal
    2. PowerShell 5.1 PnP device removal
    3. DevCon utility removal (if available)
    4. Registry key cleanup
    
    Each phase includes user confirmation (unless in headless mode) and comprehensive logging.

.PARAMETER Headless
    Runs the script without user prompts, automatically proceeding through all phases.
    Useful for automated deployments or when running from other scripts.

.EXAMPLE
    .\Remove-BluetoothDevice.ps1
    Runs the script with interactive prompts for each phase.

.EXAMPLE
    .\Remove-BluetoothDevice.ps1 -Headless
    Runs the script automatically without user prompts.

.NOTES
    Author: PowerShell Style Guide Compliant
    Prerequisites: Windows PowerShell 5.1 or PowerShell 7+
    Optional: Chocolatey + devcon.portable for enhanced removal capabilities
    Requires: Administrative privileges for registry modifications
    Output: Log file on desktop with timestamp
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Headless
)

# Define script-level variables
$DeviceName = "NuPhy Air75 V2-1"
$MacPartial = "FD58147B5AE5"
$LogFile = Join-Path $env:USERPROFILE "Desktop\Remove-BluetoothDevice_Log_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"
$RegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Devices"
$BackupPath = Join-Path $env:USERPROFILE "Desktop\Backup_BTH_$MacPartial.reg"

# Start comprehensive logging
Start-Transcript -Path $LogFile -Append

function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $levelIcon = switch ($Level) {
        'Info' { 'ℹ️' }
        'Warning' { '⚠️' }
        'Error' { '❌' }
        'Success' { '✅' }
    }
    $logMessage = "[$timestamp] $levelIcon $Message"
    Write-Output $logMessage
}

function Test-IsAdmin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function Confirm-NextPhase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )
    
    Write-Log "=============================" -Level Info
    Write-Log "🧭 $Message" -Level Info
    Write-Log "=============================" -Level Info
    
    if (-not $Headless) {
        $input = Read-Host "Continue to next phase? (Y/N)"
        if ($input -notmatch '^[Yy]$') {
            Write-Log "Script stopped by user." -Level Warning
            Stop-Transcript
            exit
        }
    } else {
        Write-Log "Headless mode enabled — proceeding automatically." -Level Success
    }
}

function Remove-DeviceViaWMI {
    [CmdletBinding()]
    param()
    
    Write-Log "Attempting to find device via Win32_PnPEntity..." -Level Info
    
    try {
        $btDevices = Get-CimInstance Win32_PnPEntity | Where-Object { 
            $_.Name -like "*$DeviceName*" -or $_.DeviceID -like "*$MacPartial*" 
        }
        
        if ($btDevices) {
            foreach ($device in $btDevices) {
                Write-Log "Found: $($device.Name)" -Level Success
                try {
                    $device | Invoke-CimMethod -MethodName "Disable"
                    Start-Sleep -Seconds 2
                    $device | Invoke-CimMethod -MethodName "Delete"
                    Write-Log "WMI removal attempted. Check if device is gone." -Level Success
                } catch {
                    Write-Log "WMI removal failed: $($_.Exception.Message)" -Level Error
                }
            }
        } else {
            Write-Log "No matching device found in WMI." -Level Warning
        }
    } catch {
        Write-Log "Error accessing WMI: $($_.Exception.Message)" -Level Error
    }
}

function Remove-DeviceViaPnP {
    [CmdletBinding()]
    param()
    
    if ($PSVersionTable.PSVersion.Major -eq 5) {
        try {
            Import-Module PnpDevice -ErrorAction Stop
            $pnp = Get-PnpDevice -Class Bluetooth | Where-Object { 
                $_.FriendlyName -like "*$DeviceName*" 
            }
            
            if ($pnp) {
                $pnp | ForEach-Object {
                    Write-Log "Removing $($_.FriendlyName)..." -Level Info
                    Remove-PnpDevice -InstanceId $_.InstanceId -Confirm:$false
                }
            } else {
                Write-Log "No matching PnP device found." -Level Info
            }
        } catch {
            Write-Log "Could not load PnpDevice module or run Remove-PnpDevice: $($_.Exception.Message)" -Level Warning
        }
    } else {
        Write-Log "PowerShell version is not 5.1. Skipping this phase." -Level Warning
    }
}

function Remove-DeviceViaDevCon {
    [CmdletBinding()]
    param()
    
    $devconPath = "devcon64.exe"
    $foundViaDevcon = $false
    
    if (Get-Command $devconPath -ErrorAction SilentlyContinue) {
        try {
            $result = & $devconPath find "*$MacPartial*" 2>&1
            $match = $result | Select-String "$MacPartial"
            
            if ($match) {
                $devID = $match.ToString().Split(":")[0].Trim()
                Write-Log "DevCon removing device ID: $devID" -Level Info
                & $devconPath remove "$devID"
                $foundViaDevcon = $true
            } else {
                Write-Log "DevCon could not find device ID with: $MacPartial" -Level Info
            }
        } catch {
            Write-Log "DevCon execution failed: $($_.Exception.Message)" -Level Error
        }
    } else {
        Write-Log "DevCon not available. Install via Chocolatey: choco install devcon.portable" -Level Warning
    }
}

function Remove-DeviceViaRegistry {
    [CmdletBinding()]
    param()
    
    $keyPath = Join-Path $RegPath $MacPartial
    
    if (Test-Path $keyPath) {
        try {
            # Create backup before removal
            reg export "$RegPath\$MacPartial" "$BackupPath" /y | Out-Null
            Remove-Item -Path $keyPath -Recurse -Force
            Write-Log "Registry key removed and backup saved to: $BackupPath" -Level Success
        } catch {
            Write-Log "Registry removal failed: $($_.Exception.Message)" -Level Error
        }
    } else {
        Write-Log "Could not find registry key for MAC: $MacPartial" -Level Warning
    }
}

function Main {
    [CmdletBinding()]
    param()
    
    # Check for administrative privileges
    if (-not (Test-IsAdmin)) {
        Write-Log "This script requires administrative privileges." -Level Error
        Write-Log "Please run PowerShell as Administrator and try again." -Level Info
        Stop-Transcript
        exit 1
    }
    
    Write-Log "Starting Bluetooth device removal process..." -Level Info
    Write-Log "Target device: $DeviceName" -Level Info
    Write-Log "MAC partial: $MacPartial" -Level Info
    Write-Log "Log file: $LogFile" -Level Info
    
    # Phase 1: WMI/CIM removal
    Remove-DeviceViaWMI
    Confirm-NextPhase "Phase 2: Attempt removal via Windows PowerShell 5.1 (if available)"
    
    # Phase 2: PowerShell 5.1 PnP removal
    Remove-DeviceViaPnP
    Confirm-NextPhase "Phase 3: Attempt removal via DevCon if available"
    
    # Phase 3: DevCon removal
    Remove-DeviceViaDevCon
    Confirm-NextPhase "Final Phase: Remove registry key if device is still stuck"
    
    # Phase 4: Registry cleanup
    Remove-DeviceViaRegistry
    
    Write-Log "Bluetooth device removal process completed." -Level Success
    Write-Log "Reboot required to finalize removal. Please restart your system." -Level Warning
}

# Execute main function
Main

# Stop logging
Stop-Transcript 
<# 
.SYNOPSIS
  Disables or re-enables Bluetooth "Hands-Free / HFP (AG Audio)" endpoints that force low-quality audio,
  and sets Communications behavior to "Do nothing". Optional: disable system-wide HFP service.

.EXAMPLES
  # Disable hands-free endpoints and stop Windows from ducking volume
  .\Fix-BTHandsFree.ps1 -Disable

  # Same as above + also disable the Bluetooth Handsfree service (system-wide HFP off)
  .\Fix-BTHandsFree.ps1 -Disable -SystemWideHfp

  # Roll back: re-enable previously disabled endpoints and restore service
  .\Fix-BTHandsFree.ps1 -Enable -SystemWideHfp
#>

[CmdletBinding(SupportsShouldProcess)]
param(
  [switch]$Disable,
  [switch]$Enable,
  [switch]$SystemWideHfp
)

# --- Safety checks ---
if (-not ($Disable -xor $Enable)) {
  Write-Error "Choose exactly one: -Disable OR -Enable."
  exit 1
}

# Require elevation for device/service changes
$IsElevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsElevated) {
  Write-Error "This script must be run as Administrator."
  exit 1
}

# Ensure PnpDevice module is present
if (-not (Get-Module -ListAvailable -Name PnpDevice)) {
  try { Import-Module PnpDevice -ErrorAction Stop } catch {
    Write-Error "PnpDevice module not available. Use PowerShell 5.1+ or 7+ on Windows."
    exit 1
  }
} else {
  Import-Module PnpDevice | Out-Null
}

# Paths for backup state
$StateDir  = Join-Path $env:ProgramData "BTHandsFreeFix"
$StateFile = Join-Path $StateDir "disabled_endpoints.json"

# Helper: save/restore JSON
function Save-State($obj) {
  if (-not (Test-Path $StateDir)) { New-Item -Path $StateDir -ItemType Directory -Force | Out-Null }
  $obj | ConvertTo-Json -Depth 5 | Set-Content -Path $StateFile -Encoding UTF8
}
function Load-State {
  if (Test-Path $StateFile) {
    try { Get-Content -Raw -Path $StateFile | ConvertFrom-Json } catch { $null }
  }
}

# 1) COMMUNICATIONS: stop Windows from ducking volume (does not require elevation but we’re elevated anyway)
# HKCU\Software\Microsoft\Multimedia\Audio\Communications\UserPreference
# 0 = Mute all, 1 = Reduce 80%, 2 = Reduce 50%, 3 = Do nothing
function Set-CommunicationsDoNothing {
  try {
    $key = 'HKCU:\Software\Microsoft\Multimedia\Audio\Communications'
    if (-not (Test-Path $key)) { New-Item $key -Force | Out-Null }
    New-ItemProperty -Path $key -Name 'UserPreference' -PropertyType DWord -Value 3 -Force | Out-Null
    Write-Host "Set Communications behavior to 'Do nothing' for current user."
  } catch {
    Write-Warning "Failed to set Communications behavior: $($_.Exception.Message)"
  }
}

# 2) Identify HFP/Hands-Free endpoints and enumerator devices
function Get-HandsFreeDevices {
  $candidates = @()

  # Audio endpoints with Hands-Free / AG Audio identifiers
  $endpointClasses = @('AudioEndpoint','MEDIA')
  foreach ($cls in $endpointClasses) {
    try {
      $devs = Get-PnpDevice -PresentOnly -Class $cls -ErrorAction SilentlyContinue
      if ($devs) {
        $candidates += $devs | Where-Object {
          $_.FriendlyName -match '(?i)(hands[-\s]?free|ag audio|hfp|headset)' -or
          $_.InstanceId   -match '(?i)BTHHFENUM'
        }
      }
    } catch { }
  }

  # Direct Bluetooth Handsfree enumerator nodes
  try {
    $bt = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object {
      $_.InstanceId -match '(?i)BTHHFENUM'
    }
    if ($bt) { $candidates += $bt }
  } catch { }

  # De-dup by InstanceId
  $candidates | Sort-Object InstanceId -Unique
}

# 3) System-wide Handsfree service (optional)
$HfpServiceName = 'BthHFSrv'  # Bluetooth Handsfree Service

function Disable-HfpService {
  try {
    $svc = Get-Service -Name $HfpServiceName -ErrorAction Stop
    if ($svc.Status -ne 'Stopped') {
      Stop-Service -Name $HfpServiceName -Force -ErrorAction Stop
    }
    Set-Service -Name $HfpServiceName -StartupType Disabled
    Write-Host "Disabled and stopped Bluetooth Handsfree service ($HfpServiceName)."
  } catch {
    Write-Warning "Could not disable $HfpServiceName $($_.Exception.Message)"
  }
}

function Enable-HfpService {
  try {
    Set-Service -Name $HfpServiceName -StartupType Manual
    Start-Service -Name $HfpServiceName
    Write-Host "Re-enabled and started Bluetooth Handsfree service ($HfpServiceName)."
  } catch {
    Write-Warning "Could not re-enable $HfpServiceName $($_.Exception.Message)"
  }
}

# 4) Disable / Enable endpoints
function Disable-HandsFreeEndpoints {
  $toDisable = Get-HandsFreeDevices
  if (-not $toDisable) {
    Write-Host "No Hands-Free (HFP/AG Audio) endpoints found."
    return
  }

  # Save current disabled set so we can re-enable only what we changed
  $state = @{
    Timestamp = (Get-Date).ToString("s")
    Devices   = @()
  }

  foreach ($dev in $toDisable) {
    try {
      if ($PSCmdlet.ShouldProcess($dev.FriendlyName, "Disable-PnpDevice")) {
        Disable-PnpDevice -InstanceId $dev.InstanceId -Confirm:$false -ErrorAction Stop
        $state.Devices += @{
          InstanceId   = $dev.InstanceId
          FriendlyName = $dev.FriendlyName
          Class        = $dev.Class
        }
        Write-Host ("Disabled: {0} [{1}]" -f $dev.FriendlyName, $dev.InstanceId)
      }
    } catch {
      Write-Warning ("Failed to disable {0}: {1}" -f $dev.FriendlyName, $_.Exception.Message)
    }
  }

  if ($state.Devices.Count -gt 0) { Save-State $state }
}

function Enable-HandsFreeEndpoints {
  $state = Load-State
  if (-not $state -or -not $state.Devices) {
    Write-Host "No prior state file found. Attempting best-effort re-enable of HFP endpoints..."
    $devs = Get-HandsFreeDevices
    if ($devs) {
      foreach ($d in $devs) {
        try {
          Enable-PnpDevice -InstanceId $d.InstanceId -Confirm:$false -ErrorAction Stop
          Write-Host ("Enabled: {0} [{1}]" -f $d.FriendlyName, $d.InstanceId)
        } catch {
          Write-Warning ("Failed to enable {0}: {1}" -f $d.FriendlyName, $_.Exception.Message)
        }
      }
    } else {
      Write-Host "No matching endpoints to re-enable."
    }
    return
  }

  foreach ($d in $state.Devices) {
    try {
      Enable-PnpDevice -InstanceId $d.InstanceId -Confirm:$false -ErrorAction Stop
      Write-Host ("Enabled: {0} [{1}]" -f $d.FriendlyName, $d.InstanceId)
    } catch {
      Write-Warning ("Failed to enable {0}: {1}" -f $d.FriendlyName, $_.Exception.Message)
    }
  }

  # Clean up state after successful enable
  try { Remove-Item $StateFile -Force -ErrorAction SilentlyContinue } catch { }
}

# --- Execute ---
Set-CommunicationsDoNothing

if ($Disable) {
  Disable-HandsFreeEndpoints
  if ($SystemWideHfp) { Disable-HfpService }
  Write-Host "`nDone. Your headset should stick to the high-quality Stereo/A2DP profile. If Windows used the mic as default device, switch Input to another mic in Sound Settings."
}
elseif ($Enable) {
  Enable-HandsFreeEndpoints
  if ($SystemWideHfp) { Enable-HfpService }
  Write-Host "`nRestored Hands-Free endpoints (and service if requested)."
}

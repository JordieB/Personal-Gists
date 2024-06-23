# Function to check if the script is running as admin
function Test-IsAdmin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

# Restart the script with admin privileges if not already running as admin
if (-not (Test-IsAdmin)) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Enable script logging
Start-Transcript -Path "$env:TEMP\Full-Uninstall-Vortex-and-Valheim.log" -Append

# Function to log messages with timestamps
function Log-Message {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$timestamp - $message"
}

# Function to handle errors and keep console open
function Handle-Error {
    param (
        [string]$message
    )
    Log-Message "ERROR: $message"
    Log-Message "Press Enter to exit..."
    Read-Host
    Stop-Transcript
    exit 1
}

# Function to interact with SteamCMD process
function Run-SteamCMD {
    param (
        [string]$arguments,
        [string]$steamUser,
        [string]$steamPass
    )

    $steamCmdPath = "C:\ProgramData\chocolatey\lib\steamcmd\tools\steamcmd.exe"
    if (-Not (Test-Path $steamCmdPath)) {
        Handle-Error "SteamCMD executable not found at $steamCmdPath"
    }

    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $steamCmdPath
    $processInfo.Arguments = $arguments
    $processInfo.RedirectStandardInput = $true
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    $process.Start() | Out-Null

    $process.StandardInput.WriteLine("+login $steamUser $steamPass")
    Start-Sleep -Seconds 2

    $output = $process.StandardOutput.ReadToEnd()

    if ($output -match "Steam Guard code:") {
        $steamGuardCode = Read-Host -Prompt "Enter Steam Guard code from your email"
        $process.StandardInput.WriteLine($steamGuardCode)
    }

    $process.StandardInput.WriteLine("+quit")
    $process.StandardInput.Close()
    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        Handle-Error "SteamCMD command failed with exit code $($process.ExitCode)"
    }
}

try {
    # Instructions for the user
    Log-Message "Please ensure the following before proceeding:"
    Log-Message "1. Steam must be open and running."
    Log-Message "2. This script must be started in admin mode."
    Log-Message "3. You will need to provide your Steam username and password."
    Log-Message "Note: If the window hangs (no new text appears), press Enter to check the logs."

    # Pause for user to read instructions
    Log-Message "You're pausing to acknowledge info screen 1 of 2"
    Log-Message "Press Enter to continue..."
    Read-Host

    # Notify the user of the steps being taken
    Log-Message "The script will perform the following steps:"
    Log-Message "1. Close Vortex if running."
    Log-Message "2. Remove all mods from Vortex."
    Log-Message "3. Purge Vortex data."
    Log-Message "4. Uninstall Vortex."
    Log-Message "5. Check and install Chocolatey if needed."
    Log-Message "6. Install SteamCMD using Chocolatey."
    Log-Message "7. Use SteamCMD to quit and uninstall Valheim."
    Log-Message "8. Recursively clean up any leftover files."

    # Pause for user to read steps
    Log-Message "You're pausing to acknowledge info screen 2 of 2"
    Log-Message "Press Enter to continue..."
    Read-Host

    # Indicate that the script is officially starting
    Log-Message "Script is now starting..."

    Log-Message "Step 1: Closing Vortex if running"
    Stop-Process -Name "vortex" -ErrorAction SilentlyContinue

    Log-Message "Step 2: Removing all mods from Vortex"
    $vortexDir = "$env:APPDATA\Vortex"
    $gameDir = "$vortexDir\valheim"
    Remove-Item -Path "$gameDir\mods" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$gameDir\downloads" -Recurse -Force -ErrorAction SilentlyContinue

    Log-Message "Step 3: Purging Vortex data"
    Remove-Item -Path "$vortexDir\state" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$gameDir\state" -Recurse -Force -ErrorAction SilentlyContinue

    Log-Message "Step 4: Uninstalling Vortex"
    $uninstaller = Get-WmiObject -Class Win32_Product | Where-Object {$_.Name -like "Vortex*"}
    if ($uninstaller) {
        $uninstallString = $uninstaller.UninstallString
        $argsList = $uninstallString.Replace("/I","/X") + " /qn"
        $process = Start-Process "$env:SYSTEMROOT\system32\msiexec.exe" -ArgumentList $argsList -Wait -PassThru
        $process.WaitForExit()

        if ($process.ExitCode -ne 0) {
            Handle-Error "Uninstalling Vortex failed with exit code $($process.ExitCode)"
        }
    } else {
        Log-Message "Vortex is not installed."
    }

    Log-Message "Step 5: Checking and Installing Chocolatey if needed"
    if (-Not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Log-Message "Step 5.1: Installing Chocolatey"
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-WebRequest -Uri "https://chocolatey.org/install.ps1" -UseBasicParsing | Invoke-Expression | Out-Null
    }

    Log-Message "Step 5.2: Installing SteamCMD using Chocolatey"
    $process = Start-Process "choco" -ArgumentList "install steamcmd -y" -Wait -PassThru
    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        Handle-Error "Installing SteamCMD using Chocolatey failed with exit code $($process.ExitCode)"
    }

    Log-Message "Step 6: Prompting for Steam credentials"
    $steamUser = Read-Host -Prompt "Enter your Steam username"
    $steamPass = Read-Host -Prompt "Enter your Steam password" -AsSecureString
    $steamPassUnsecure = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($steamPass))

    Log-Message "Step 7: Using SteamCMD to quit and uninstall Valheim"
    
    Log-Message "Step 7.1: Quitting Valheim (ID 892970)"
    Run-SteamCMD "+app_stop 892970" $steamUser $steamPassUnsecure

    Log-Message "Step 7.2: Uninstalling Valheim (ID 892970)"
    Run-SteamCMD "+app_uninstall 892970" $steamUser $steamPassUnsecure

    Log-Message "Step 8: Recursively cleaning up any leftover files"
    $valheimDir = "$env:PROGRAMFILES\Steam\steamapps\common\Valheim"
    if (Test-Path $valheimDir) {
        Remove-Item -Path "$valheimDir\*" -Recurse -Force
    }

    Log-Message "Process completed successfully. Press Enter to exit..."
    Read-Host
}
catch {
    Handle-Error $_.Exception.Message
}
finally {
    Stop-Transcript
}

# <#
# .SYNOPSIS
#     Toggles Malwarebytes and Windows Defender services.

# .DESCRIPTION
#     The Toggle-SecurityServices function enables or disables Malwarebytes and Windows Defender services based on user input. 
#     It's designed to quickly switch the security services for scenarios like software installation where these services might interfere.

# .PARAMETER Action
#     A string parameter that accepts either 'On' or 'Off' to toggle the services accordingly.

# .EXAMPLE
#     Toggle-SecurityServices -Action 'Off'
#     Disables Malwarebytes and Windows Defender.

# .EXAMPLE
#     Toggle-SecurityServices -Action 'On'
#     Enables Malwarebytes and Windows Defender.

# .NOTES
#     Requires administrative privileges to modify service states. Ensure you understand the security implications of disabling these services.
# #>
# function Toggle-SecurityServices {
#     [CmdletBinding()]
#     param (
#         [Parameter(Mandatory)]
#         [ValidateSet('On', 'Off')]
#         [string]$Action
#     )

#     # Toggles the Malwarebytes application
#     function Toggle-Malwarebytes {
#         param (
#             [string]$State
#         )

#         # List of all processes that might be associated with Malwarebytes
#         $malwarebytesProcesses = @("Malwarebytes", "MBAMService", "MBAMTrap")

#         if ($State -eq 'Off') {
#             # Attempt to stop each Malwarebytes-related process
#             foreach ($process in $malwarebytesProcesses) {
#                 Get-Process -Name $process -ErrorAction SilentlyContinue | Stop-Process -Force
#             }
#             Write-Host "Attempted to terminate all Malwarebytes-related processes."
#         } else {
#             Start-Process -FilePath "C:\Program Files\Malwarebytes\Anti-Malware\mbam.exe" -ErrorAction SilentlyContinue
#             Write-Host "Malwarebytes application started."
#         }
#     }

#     # Toggles the Windows Defender service
#     function Toggle-WindowsDefender {
#         param (
#             [string]$State
#         )

#         if ($State -eq 'Off') {
#             Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
#             Write-Host "Windows Defender Real-Time Monitoring disabled."
#         } else {
#             Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
#             Write-Host "Windows Defender Real-Time Monitoring enabled."
#         }
#     }

#     # Main logic to toggle services based on the action
#     if ($Action) {
#         Toggle-Malwarebytes -State $Action
#         Toggle-WindowsDefender -State $Action
#         Write-Host "Security services have been turned $Action."
#     }
# }
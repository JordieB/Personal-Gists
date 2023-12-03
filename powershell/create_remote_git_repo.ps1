# Last error
# Line |
#  229 |  … $cloneUrl = Create-GitHubRepo -Token $token -RepoName $RepoName -Desc …
#  |                ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  | GitHub repository does not exist and cannot be fetched. URL Checked: https://api.github.com/repos/JordieB/Personal+PowerShell+Scripts

# <#
# .SYNOPSIS
# This script creates a GitHub repository, initializes a local git repository, adds .gitignore, README.md, commits the initial code, and pushes to GitHub.

# .DESCRIPTION
# The script performs the following steps:
# 1. Initialize a local git repository if it doesn't exist.
# 2. Fetches the standard Python .gitignore if it's not present in the current directory.
# 3. Creates a README.md file if it's not present.
# 4. Adds the specified license to the repository.
# 5. Commits the initial code to the local git repository.
# 6. Creates a new GitHub repository using the provided GitHub token.
# 7. Pushes the local code to the new GitHub repository.

# .PARAMETER PlainSecretStorePassword
# The password to unlock the SecretStore where the GitHub token is stored.

# .PARAMETER RepoName
# The name of the repository to be created on GitHub.

# .PARAMETER Description
# The description of the repository to be created on GitHub.

# .PARAMETER LicenseType
# The type of license to be added to the repository.

# .PARAMETER TargetDirectory
# The path to the directory you wish to turn into a GitHub repository.

# .NOTES
# - Ensure that the SecretStore module is installed and that a GitHub Personal Access Token has been stored in it with the name "GitHubToken".
# - The GitHub token must have the necessary permissions to create repositories.

# .EXAMPLE
# .\CreateGithubRepo.ps1 -PlainSecretStorePassword "YourPassword" -RepoName "MyNewRepo" -Description "My new repo's description" -LicenseType "GPL-3.0" -TargetDirectory "C:\Path\To\Your\Project"
# #>

# param (
#     [Parameter(Mandatory=$false)]
#     [string]$PlainSecretStorePassword,

#     [Parameter(Mandatory=$false)]
#     [string]$RepoName,

#     [Parameter(Mandatory=$false)]
#     [string]$Description,

#     [Parameter(Mandatory=$false)]
#     [string]$LicenseType,

#     [Parameter(Mandatory=$false)]
#     [string]$TargetDirectory
# )

# function Get-GitHubToken {
#     param (
#         [Parameter(Mandatory=$true)]
#         [securestring]$SecretStorePassword
#     )

#     try {
#         Unlock-SecretStore -Password $SecretStorePassword
#         return Get-Secret -Name "GITHUB_PAT" -AsPlainText
#     } catch {
#         Write-Error "Error unlocking SecretStore or retrieving GitHub token: $($_.Exception.Message)"
#         exit
#     }
# }

# function Initialize-LocalGitRepo {
#     # ... (rest of the function)
#     try {
#         git init
#     } catch {
#         Write-Error "Error initializing local git repo: $($_.Exception.Message)"
#         exit
#     }
# }


# function Add-GitIgnore {
#     # Fetch standard Python .gitignore if not present
#     if (-not (Test-Path .gitignore)) {
#         Write-Host "Fetching standard Python .gitignore..."
#         Invoke-WebRequest -Uri "https://raw.githubusercontent.com/github/gitignore/master/Python.gitignore" -OutFile .gitignore
#     }
# }

# function Add-Readme {
#     param (
#         [Parameter(Mandatory=$true)]
#         [string]$RepoName
#     )

#     # Create a simple README.md if not present
#     if (-not (Test-Path README.md)) {
#         Write-Host "Creating README.md..."
#         "## $RepoName" | Set-Content -Path README.md
#     }
# }

# function Add-License {
#     param (
#         [Parameter(Mandatory=$true)]
#         [string]$LicenseType
#     )

#     # Create a license file based on the specified license type
#     Write-Host "Fetching license..."
#     Invoke-WebRequest -Uri "https://api.github.com/licenses/$LicenseType" | ConvertFrom-Json | Select-Object -ExpandProperty body | Set-Content -Path LICENSE
# }

# function Commit-LocalGitRepo {
#     Write-Host "Committing files to local git..."
#     git add .
#     git commit -m "Initial commit"
# }

# function Create-GitHubRepo {
#     param (
#         [Parameter(Mandatory=$true)]
#         [string]$Token,
#         [Parameter(Mandatory=$true)]
#         [string]$RepoName,
#         [Parameter(Mandatory=$true)]
#         [string]$Description,
#         [bool]$Private = $false
#     )

#     Write-Host "Attempting to create remote GitHub repository..."

#     $headers = @{
#         Authorization = "token $Token"
#     }
#     $body = @{
#         name        = $RepoName
#         description = $Description
#         private     = $Private
#     }

#     try {
#         $response = Invoke-RestMethod -Method POST -Headers $headers -Body ($body | ConvertTo-Json) -Uri "https://api.github.com/user/repos"
#         return $response.clone_url
#     } catch {
#         if ($_.Exception.Response.StatusCode -eq 422) { # 422 means validation failed, which typically means the repo already exists
#             Write-Host "Repository already exists. Fetching its clone URL..."
#             try {
#                 $githubUserResponse = Invoke-RestMethod -Method GET -Headers $headers -Uri "https://api.github.com/user"
#                 $githubUsername = $githubUserResponse.login
        
#                 Write-Host "Fetching repository for user: $githubUsername"
#                 $encodedRepoName = [System.Web.HttpUtility]::UrlEncode($RepoName)
#                 $fetchRepoURL = "https://api.github.com/repos/$githubUsername/$encodedRepoName"
#                 Write-Host "Checking URL: $fetchRepoURL"
        
#                 $existingRepoResponse = Invoke-RestMethod -Method GET -Headers $headers -Uri $fetchRepoURL
#                 return $existingRepoResponse.clone_url
#             } catch {
#                 if ($_.Exception.Response.StatusCode -eq 404) {
#                     Write-Error "GitHub repository does not exist and cannot be fetched. URL Checked: $fetchRepoURL"
#                     exit
#                 } else {
#                     Write-Error "Error fetching existing GitHub repository details: $($_.Exception.Message)"
#                     exit
#                 }
#             }
#         } else {
#             Write-Error "Error creating GitHub repository: $($_.Exception.Message)"
#             exit
#         }
#     }
# }

# function Push-To-GitHub {
#     param (
#         [Parameter(Mandatory=$true)]
#         [string]$CloneUrl
#     )

#     if (-not $CloneUrl) {
#         Write-Error "Clone URL is empty or invalid."
#         exit
#     }

#     try {
#         git remote add origin $CloneUrl
#         git push -u origin main
#     } catch {
#         Write-Error "Error pushing to GitHub repository: $($_.Exception.Message)"
#         exit
#     }
# }

# # Main script execution starts here

# # Check and prompt for SecretStore password if not provided
# if (-not $PlainSecretStorePassword) {
#     $PlainSecretStorePassword = Read-Host "Enter SecretStore password"
# }
# $SecretStorePassword = $PlainSecretStorePassword | ConvertTo-SecureString -AsPlainText -Force
# $token = Get-GitHubToken -SecretStorePassword $SecretStorePassword

# if (-not $RepoName) {
#     $RepoName = Read-Host "Enter the name of the repository"
# }

# if (-not $Description) {
#     $Description = Read-Host "Enter the repo description"
# }

# if (-not $LicenseType) {
#     $LicenseType = Read-Host "Enter the license type (e.g., GPL-3.0)"
# }

# # Change to the target directory
# if ($TargetDirectory) {
#     Set-Location -Path $TargetDirectory
# } else {
#     $TargetDirectory = Read-Host "Enter the target directory"
#     Set-Location -Path $TargetDirectory
# }

# try {
#     Initialize-LocalGitRepo
#     Add-GitIgnore
#     Add-Readme -RepoName $RepoName
#     Add-License -LicenseType $LicenseType
#     Commit-LocalGitRepo
#     $cloneUrl = Create-GitHubRepo -Token $token -RepoName $RepoName -Description $Description
#     Push-To-GitHub -CloneUrl $cloneUrl
#     Write-Output "Repository successfully created and pushed!"
# } catch {
#     Write-Error "An error occurred during the main execution: $($_.Exception.Message)"
# }

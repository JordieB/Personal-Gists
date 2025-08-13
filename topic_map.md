# Topic Mapping Reasoning

This document explains the reasoning behind topic classification for each script in the repository.

## Topic Definitions

- **api-integration**: Scripts that interact with web APIs and third-party services
- **data-science**: Scripts for data processing, ETL, modeling, and data science project management
- **dev-tools**: Development environment setup, utilities, and general programming tools
- **document-tools**: File format conversion and document processing utilities
- **file-utilities**: File system operations, navigation, and organization tools
- **misc-tools**: Scripts that don't clearly fit into other categories
- **package-management**: Package managers (Chocolatey, etc.) and software installation automation
- **python-tools**: Python-specific development tools (Poetry, venv, dependencies)
- **software-management**: Installing, uninstalling, and managing specific software applications
- **system-admin**: System administration tasks (services, devices, configurations)
- **system-maintenance**: Automated system maintenance and cleanup routines

## Script Classifications

### PowerShell Scripts

| Script | Topic | Reasoning |
|--------|-------|-----------|
| `Backup-ReWASDConfigs.ps1` | system-admin | Backs up system configuration files for ReWASD hardware controller software |
| `Bump-Poetry-Deps-Latest.ps1` | python-tools | Updates Poetry dependencies - Python package management tool |
| `Create-DSProj.ps1` | data-science | Creates scaffolding for data science projects with standard directory structure |
| `Create-IndexShortcuts.ps1` | file-utilities | Creates shortcuts for file navigation and organization |
| `Create-PythonVirtualEnv.ps1` | python-tools | Creates and manages Python virtual environments using pyenv |
| `Display-DirectoryTree.ps1` | file-utilities | Displays directory structure in tree format - file system utility |
| `Ensure-PoetryAvailability.ps1` | python-tools | Ensures Poetry is installed and available - Python package management |
| `Example-PSProfileWithSourcedFuncs.ps1` | dev-tools | PowerShell profile configuration for development environment |
| `Full-Uninstall-Vortex-and-Valheim.ps1` | software-management | Complete removal of specific gaming software applications |
| `Install-ChocoSoftware.ps1` | package-management | Automated installation using Chocolatey package manager |
| `Maintain-Choco.ps1` | package-management | Maintenance and updates for Chocolatey package manager |
| `profile.ps1` | dev-tools | PowerShell profile for development environment customization |
| `Remove-BluetoothDevice.ps1` | system-admin | Manages Bluetooth devices at system level |
| `Remove-Edge.ps1` | software-management | Removes Microsoft Edge browser and prevents reinstallation |
| `Set-SpotifyPlaylistsPrivate.ps1` | api-integration | Interacts with Spotify Web API to modify playlist privacy settings |
| `Start-Albion-Data-Project.ps1` | misc-tools | Project-specific script that doesn't fit clearly in other categories |
| `Toggle-SecurityServices.ps1` | system-admin | Manages security services (Defender, Malwarebytes) at system level |
| `Update-PythonDependencies.ps1` | python-tools | Updates Python packages and dependencies |

### Python Scripts

| Script | Topic | Reasoning |
|--------|-------|-----------|
| `datasets.py` | data-science | Contains utilities for dataset optimization and conversion for ML workflows |
| `etl_focused.py` | data-science | ETL (Extract, Transform, Load) utilities for data processing pipelines |
| `general.py` | dev-tools | General-purpose utility functions for Python development projects |
| `modeling_focused.py` | data-science | Machine learning modeling utilities and helper functions |
| `pdf_to_md.py` | document-tools | Converts PDF files to Markdown format - document processing |

### Zsh Scripts

| Script | Topic | Reasoning |
|--------|-------|-----------|
| `macos_maintenance.sh` | system-maintenance | Comprehensive automated maintenance script for macOS systems |

### Command Prompt Scripts

| Script | Topic | Reasoning |
|--------|-------|-----------|
| `open_vsc_with_wsl.bat` | dev-tools | Opens VSCode with WSL remote connection - development environment tool |

## Topic Consolidation Strategy

During module creation, some topics may be consolidated if they have very few scripts:

- **misc-tools** scripts should be reviewed for better categorization or merged with related topics
- Topics with only 1-2 scripts may be combined with closely related topics
- **python-tools** and **package-management** have some overlap but serve different primary purposes

## Naming Convention Mapping

- **Folder names**: kebab-case (e.g., `data-science`, `python-tools`)
- **Python packages**: snake_case (e.g., `data_science`, `python_tools`)
- **PowerShell modules**: PascalCase (e.g., `DataScience`, `PythonTools`)
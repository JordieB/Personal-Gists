# Snippets Modules Index

This repository provides reusable modules across PowerShell, Python, Zsh, and Command Prompt, organized by topic for common development and administration tasks.

## Available Modules

### API Integration
- **PowerShell**: [api-integration](../modules/powershell/api-integration/) - Tools for integrating with web APIs and third-party services
  - Set-SpotifyPlaylistPrivacy: Manage Spotify playlist privacy settings

### Data Science
- **PowerShell**: [data-science](../modules/powershell/data-science/) - Data science project scaffolding and management tools
- **Python**: [data-science](../modules/python/data-science/) - Dataset processing and ML utilities

### Development Tools
- **PowerShell**: [dev-tools](../modules/powershell/dev-tools/) - Development environment utilities
- **Python**: [dev-tools](../modules/python/dev-tools/) - General development utilities and project helpers
- **Command Prompt**: [dev-tools](../modules/command_prompt/dev-tools/) - VSCode and development shortcuts

### Document Tools
- **Python**: [document-tools](../modules/python/document-tools/) - Document conversion and processing utilities

### File Utilities
- **PowerShell**: [file-utilities](../modules/powershell/file-utilities/) - File system operations and navigation tools

### Package Management
- **PowerShell**: [package-management](../modules/powershell/package-management/) - Chocolatey and software installation automation

### Python Tools
- **PowerShell**: [python-tools](../modules/powershell/python-tools/) - Python development environment management (Poetry, venv, etc.)

### Software Management
- **PowerShell**: [software-management](../modules/powershell/software-management/) - Installing, uninstalling, and managing software applications

### System Administration
- **PowerShell**: [system-admin](../modules/powershell/system-admin/) - System administration tasks and configuration management

### System Maintenance
- **Zsh**: [system-maintenance](../modules/zsh/system-maintenance/) - Automated system maintenance routines

### Miscellaneous Tools
- **PowerShell**: [misc-tools](../modules/powershell/misc-tools/) - Utilities that don't fit into other categories

## Getting Started

### Prerequisites
- **PowerShell**: 5.1 or 7.x
- **Python**: 3.9 or higher
- **Zsh**: 5.x
- **Windows Command Prompt**: Any recent version

### Installation

Each module can be installed and used independently:

```powershell
# PowerShell modules
Import-Module ./modules/powershell/<topic>/<Topic>.psd1
```

```bash
# Python modules
pip install -e ./modules/python/<topic>
```

```bash
# Zsh plugins
source modules/zsh/<topic>/<topic>.plugin.zsh
```

```cmd
# Command Prompt scripts
call modules/command_prompt/<topic>/<topic>.cmd
```

## Module Structure

Each module follows a consistent structure:
- `README.md` - Module documentation and usage examples
- `examples/` - Complete usage examples
- `tests/` - Unit and integration tests
- Language-specific files (`.psm1/.psd1`, `pyproject.toml`, `.plugin.zsh`, `.cmd`)

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines on adding new snippets and modules.

## Testing

The repository includes CI/CD pipelines for all supported languages:
- PowerShell: PSScriptAnalyzer + Pester
- Python: Ruff + Black + pytest
- Shell: shellcheck + bats

## License

See [LICENSE](../LICENSE) for license information.
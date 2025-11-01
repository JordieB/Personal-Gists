# Snippets Modules Index

This repository provides reusable modules across PowerShell, Python, Zsh, and Command Prompt, organized by topic for common development and administration tasks.

## Module Status

**Note:** Most modules are currently **stubs** (placeholders) with example functions. They are planned for future implementation. The original scripts that will be converted into these modules are located in `powershell/`, `python/`, `zsh/`, and `command_prompt/` directories, with preserved copies in `snippets/`.

- ✅ **Implemented**: Modules with actual functionality
- 🔨 **Stub**: Placeholder modules planned for implementation

See each module's README for details on planned implementation and which scripts will be converted.

## Available Modules

### API Integration
- **PowerShell**: [api-integration](../modules/powershell/api-integration/) ✅ - Tools for integrating with web APIs and third-party services
  - Set-SpotifyPlaylistPrivacy: Manage Spotify playlist privacy settings

### Data Science
- **PowerShell**: [data-science](../modules/powershell/data-science/) 🔨 - Data science project scaffolding and management tools (stub)
- **Python**: [data-science](../modules/python/data-science/) 🔨 - Dataset processing and ML utilities (stub)

### Development Tools
- **PowerShell**: [dev-tools](../modules/powershell/dev-tools/) 🔨 - Development environment utilities (stub)
- **Python**: [dev-tools](../modules/python/dev-tools/) 🔨 - General development utilities and project helpers (stub)
- **Command Prompt**: [dev-tools](../modules/command_prompt/dev-tools/) 🔨 - VSCode and development shortcuts (stub)

### Document Tools
- **Python**: [document-tools](../modules/python/document-tools/) 🔨 - Document conversion and processing utilities (stub)

### File Utilities
- **PowerShell**: [file-utilities](../modules/powershell/file-utilities/) 🔨 - File system operations and navigation tools (stub)

### Package Management
- **PowerShell**: [package-management](../modules/powershell/package-management/) 🔨 - Chocolatey and software installation automation (stub)

### Python Tools
- **PowerShell**: [python-tools](../modules/powershell/python-tools/) 🔨 - Python development environment management (Poetry, venv, etc.) (stub)

### Software Management
- **PowerShell**: [software-management](../modules/powershell/software-management/) 🔨 - Installing, uninstalling, and managing software applications (stub)

### System Administration
- **PowerShell**: [system-admin](../modules/powershell/system-admin/) 🔨 - System administration tasks and configuration management (stub)

### System Maintenance
- **Zsh**: [system-maintenance](../modules/zsh/system-maintenance/) 🔨 - Automated system maintenance routines (stub)

### Miscellaneous Tools
- **PowerShell**: [misc-tools](../modules/powershell/misc-tools/) 🔨 - Utilities that don't fit into other categories (stub)

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

## Planned Implementation

Stub modules are intended to house functions converted from the original scripts. See [`topic_map.md`](../topic_map.md) for a complete mapping of scripts to module topics. Each module's README contains details about which scripts will be converted.

## License

See [LICENSE](../LICENSE) for license information.
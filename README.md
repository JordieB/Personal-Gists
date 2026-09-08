# Personal Scripts & Modules Collection

A curated collection of reusable modules and utilities for PowerShell, Python, Zsh, and Command Prompt, organized by topic and designed for easy installation and use.

## Module Categories

| Category | Languages | Description |
|----------|-----------|-------------|
| **API Integration** | PowerShell | Web APIs and third-party service integrations |
| **Data Science** | PowerShell, Python | ML workflows, dataset processing, project scaffolding |
| **Dev Tools** | All | Development environment utilities and helpers |
| **Document Tools** | Python | File format conversion and document processing |
| **File Utilities** | PowerShell | File system operations and navigation |
| **Package Management** | PowerShell | Chocolatey and software installation automation |
| **Python Tools** | PowerShell | Python environment management (Poetry, venv) |
| **Software Management** | PowerShell | Install/uninstall and manage software applications |
| **System Admin** | PowerShell | System administration and configuration |
| **System Maintenance** | Zsh | Automated maintenance routines (macOS focus) |

## Available Modules

Status: `api-integration`, the Codex project-profile plugin, and the canonical macOS maintenance runner are implemented. The remaining language modules are placeholders with installation and public-command smoke coverage only.

### API Integration
- **PowerShell**: [api-integration](modules/powershell/api-integration/) - Tools for integrating with web APIs and third-party services
  - Set-SpotifyPlaylistPrivacy: Manage Spotify playlist privacy settings

### Data Science
- **PowerShell**: [data-science](modules/powershell/data-science/) - Data science project scaffolding and management tools
- **Python**: [data-science](modules/python/data-science/) - Dataset processing and ML utilities

### Development Tools
- **PowerShell**: [dev-tools](modules/powershell/dev-tools/) - Development environment utilities
- **Python**: [dev-tools](modules/python/dev-tools/) - General development utilities and project helpers
- **Command Prompt**: [dev-tools](modules/command_prompt/dev-tools/) - VSCode and development shortcuts
- **Zsh**: [codex-project-profiles](modules/zsh/dev-tools/codex-project-profiles/) - Automatic repository-specific Codex profile selection

### Document Tools
- **Python**: [document-tools](modules/python/document-tools/) - Document conversion and processing utilities

### File Utilities
- **PowerShell**: [file-utilities](modules/powershell/file-utilities/) - File system operations and navigation tools

### Package Management
- **PowerShell**: [package-management](modules/powershell/package-management/) - Chocolatey and software installation automation

### Python Tools
- **PowerShell**: [python-tools](modules/powershell/python-tools/) - Python development environment management (Poetry, venv, etc.)

### Software Management
- **PowerShell**: [software-management](modules/powershell/software-management/) - Installing, uninstalling, and managing software applications

### System Administration
- **PowerShell**: [system-admin](modules/powershell/system-admin/) - System administration tasks and configuration management

### System Maintenance
- **Zsh**: [system-maintenance](modules/zsh/system-maintenance/) - Placeholder plugin; the canonical [macOS maintenance runner](zsh/README.md) is implemented

### Miscellaneous Tools
- **PowerShell**: [misc-tools](modules/powershell/misc-tools/) - Utilities that don't fit into other categories

## Repository Structure

```
.
├─ modules/                    # Reusable modules by language and topic
│  ├─ powershell/<topic>/     # PowerShell modules (.psd1/.psm1)
│  ├─ python/<topic>/         # Python packages (pyproject.toml)
│  ├─ zsh/<topic>/            # Zsh plugins (.plugin.zsh)
│  └─ command_prompt/<topic>/ # Command Prompt utilities (.cmd)
├─ snippets/                   # Original scripts (preserved)
└─ README.md                  # This file
```

## License

This project is licensed under the terms specified in [LICENSE](LICENSE).

## macOS maintenance runner

See [usage, logging, installation, and tests](zsh/README.md). The canonical
`zsh/macos_maintenance.sh` runs the quick preset by default: cleanup, Homebrew, App Store updates, a macOS update check, and diagnostics. Use `--dry-run` to preview or `-y` to approve Homebrew prompts. Run as your normal user; update installation requests sudo only when explicitly selected.

See [local testing](TESTING.md) for prerequisites, platform entry points, and mock boundaries.

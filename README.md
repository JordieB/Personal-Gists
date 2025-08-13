# Personal Scripts & Modules Collection

A curated collection of reusable modules and utilities for PowerShell, Python, Zsh, and Command Prompt, organized by topic and designed for easy installation and use.

## 🚀 Quick Start

### Browse Available Modules
Visit the [📚 Module Index](docs/index.md) to explore all available modules organized by topic and language.

### Install & Use

```powershell
# PowerShell: Import any module
Import-Module ./modules/powershell/api-integration/ApiIntegration.psd1
Set-SpotifyPlaylistPrivacy -SpotifyUsername "your_username"
```

```bash
# Python: Install and use CLI tools
pip install -e ./modules/python/document-tools
document-tools --help
```

```bash
# Zsh: Source plugins
source modules/zsh/system-maintenance/system-maintenance.plugin.zsh
system_maintenance_example
```

```cmd
# Command Prompt: Run utilities
call modules/command_prompt/dev-tools/dev-tools.cmd --help
```

## 📦 Module Categories

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

## 🛠️ Features

- **Topic-Organized**: Modules grouped by functional area, not language
- **Multi-Language**: PowerShell, Python, Zsh, and Command Prompt support
- **Consistent Structure**: Every module includes docs, examples, and tests
- **CI/CD Ready**: Automated testing and linting for all languages
- **Easy Installation**: Simple import/install commands for each module
- **Production Ready**: Proper error handling, logging, and validation

## 📁 Repository Structure

```
.
├─ modules/                    # Reusable modules by language and topic
│  ├─ powershell/<topic>/     # PowerShell modules (.psd1/.psm1)
│  ├─ python/<topic>/         # Python packages (pyproject.toml)
│  ├─ zsh/<topic>/            # Zsh plugins (.plugin.zsh)
│  └─ command_prompt/<topic>/ # Command Prompt utilities (.cmd)
├─ snippets/                   # Original scripts (preserved)
├─ docs/                      # Documentation and module index
├─ .github/workflows/         # CI/CD pipelines
└─ README.md                  # This file
```

## 🧪 Quality & Testing

- **Automated Testing**: CI runs tests for all languages on every push
- **Linting**: PSScriptAnalyzer, Ruff, Black, shellcheck
- **Documentation**: Every function/command has help documentation
- **Examples**: Complete usage examples for each module
- **Error Handling**: Robust error handling and meaningful messages

### Test Status
[![CI - PowerShell](../../actions/workflows/ci-powershell.yml/badge.svg)](../../actions/workflows/ci-powershell.yml)
[![CI - Python](../../actions/workflows/ci-python.yml/badge.svg)](../../actions/workflows/ci-python.yml)
[![CI - Shell](../../actions/workflows/ci-shell.yml/badge.svg)](../../actions/workflows/ci-shell.yml)

## 📖 Documentation

- **[Module Index](docs/index.md)**: Complete list of all modules and functions
- **[Contributing Guide](CONTRIBUTING.md)**: How to add new snippets and modules
- **[Code of Conduct](CODE_OF_CONDUCT.md)**: Community guidelines

## 🤝 Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- How to add new snippets
- Module development standards
- Testing requirements  
- Pull request process

### Quick Contribution Steps
1. Add raw snippet to `/snippets/<lang>/`
2. Follow the [Snippet → Module Checklist](CONTRIBUTING.md#snippet--module-checklist)
3. Open a pull request with your module

## 🏷️ Version History

See [CHANGELOG.md](CHANGELOG.md) for version history and release notes.

## 📝 License

This project is licensed under the terms specified in [LICENSE](LICENSE).

## 🎯 Highlights

### Featured Modules

- **🎵 Spotify API Integration** (PowerShell): Bulk manage playlist privacy settings
- **📊 Data Science Scaffolding** (PowerShell): Create complete DS project structures
- **🐍 Python Environment Management** (PowerShell): Poetry and venv automation
- **🧹 macOS Maintenance** (Zsh): Comprehensive system maintenance routines
- **📄 PDF to Markdown Conversion** (Python): Convert PDF documents to Markdown

### Why This Repository?

- **Battle-Tested**: Scripts used in real development and administration workflows
- **Cross-Platform**: Works on Windows, macOS, and Linux where applicable
- **Modular Design**: Use only what you need, when you need it
- **Community-Driven**: Open to contributions and improvements
- **Well-Documented**: Every module has clear documentation and examples

---

**Quick Links**: [📚 Browse Modules](docs/index.md) | [🚀 Get Started](CONTRIBUTING.md) | [🐛 Report Issues](../../issues)

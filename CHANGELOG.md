# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Topic-based module organization across PowerShell, Python, Zsh, and Command Prompt
- Comprehensive module scaffolding with consistent structure
- CI/CD pipelines for all supported languages
- Complete documentation system with module index
- Contributing guidelines and development standards

### Changed
- Repository structure from language-first to topic-first organization
- Original scripts moved to `/snippets/` for preservation
- All modules now include tests, examples, and documentation

## [0.1.0] - 2024-01-XX

### Added

#### PowerShell Modules
- **API Integration**: Spotify playlist privacy management
- **Data Science**: Project scaffolding and setup automation
- **Dev Tools**: PowerShell profile management and development utilities
- **File Utilities**: Directory tree display and file navigation tools
- **Package Management**: Chocolatey automation and maintenance
- **Python Tools**: Poetry, venv, and dependency management
- **Software Management**: Application installation and removal
- **System Admin**: Service management, device configuration, backup utilities
- **Misc Tools**: Project-specific utilities

#### Python Modules
- **Data Science**: Dataset optimization, ETL utilities, modeling helpers
- **Dev Tools**: General project utilities and helpers
- **Document Tools**: PDF to Markdown conversion

#### Zsh Modules
- **System Maintenance**: Comprehensive macOS maintenance automation

#### Command Prompt Modules
- **Dev Tools**: VSCode WSL integration utilities

### Infrastructure
- GitHub Actions workflows for PowerShell, Python, and Shell
- PSScriptAnalyzer integration for PowerShell code quality
- Ruff and Black integration for Python code formatting
- shellcheck and bats integration for shell script testing
- Automated CI pipeline running on push and pull requests

### Documentation
- Complete module index with cross-references
- Individual module README files with installation and usage instructions
- Contributing guidelines with code standards and testing requirements
- Repository structure documentation

### Quality Assurance
- Standardized testing framework for all languages
- Linting and style checking for all code
- Example scripts for each module
- Error handling and logging standards

---

### Legend
- **Added**: New features
- **Changed**: Changes in existing functionality  
- **Deprecated**: Soon-to-be removed features
- **Removed**: Now removed features
- **Fixed**: Bug fixes
- **Security**: Vulnerability fixes
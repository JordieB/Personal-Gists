# dev-tools (Command Prompt)

**Purpose:** Tools for dev tools.

## Install
```cmd
call modules/command_prompt/dev-tools/dev-tools.cmd
```

## Usage

### Basic Usage
```cmd
dev-tools.cmd parameter
```

### Help
```cmd
dev-tools.cmd --help
```

## Examples
See the `examples/` directory for complete usage examples.

## Platform requirement
- Windows Command Prompt; not verified in the current macOS validation environment

## Notes

**Status:** 🔨 Stub Module (Planned for Implementation)

This module is currently a stub (placeholder) with example functions. It is planned for future implementation.

### Planned Implementation

This module is intended to house functions converted from the following scripts (as categorized in [Contributor Notes topic mapping](../../../CONTRIBUTOR_NOTES.md#topic-mapping)):

- `open_vsc_with_wsl.bat` - Opens VSCode with WSL remote connection - development environment tool

These scripts are located in:
- `command_prompt/` - Original working scripts
- `snippets/command_prompt/` - Preserved copies

When implemented, this module will provide reusable Command Prompt utilities for development environment tools including VSCode and WSL integration.
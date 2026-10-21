# dev_tools (Python)

**Purpose:** Tools for dev tools.

## Install
```bash
pip install -e ./modules/python/dev-tools
# For local tests:
pip install -e './modules/python/dev-tools[test]'
```

## Usage

### Command Line
```bash
dev-tools example
dev-tools example --option
```

### Python API
```python
from dev_tools import cli
cli.app()
```

## Examples
See the `examples/` directory for complete usage examples.

## Verified locally
- Python 3.9.6 and 3.14.7; package metadata supports Python 3.9+

## Notes

**Status:** 🔨 Stub Module (Planned for Implementation)

This module is currently a stub (placeholder) with example commands. It is planned for future implementation.

### Planned Implementation

This module is intended to house CLI commands converted from the following scripts (as categorized in [Contributor Notes topic mapping](../../../CONTRIBUTOR_NOTES.md#topic-mapping)):

- `general.py` - General-purpose utility functions for Python development projects

These scripts are located in:
- `python/` - Original working scripts
- `snippets/python/` - Preserved copies

When implemented, this module will provide reusable CLI commands and Python API for general development utilities and project helpers.

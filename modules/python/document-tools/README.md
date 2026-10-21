# document_tools (Python)

**Purpose:** Tools for document tools.

## Install
```bash
pip install -e ./modules/python/document-tools
# For local tests:
pip install -e './modules/python/document-tools[test]'
```

## Usage

### Command Line
```bash
document-tools example
document-tools example --option
```

### Python API
```python
from document_tools import cli
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

This module is intended to house CLI commands converted from the following scripts:

- `pdf_to_md.py` - Converts PDF files to Markdown format - document processing

These scripts are located in:
- `python/` - Original working scripts
- `snippets/python/` - Preserved copies

When implemented, this module will provide reusable CLI commands and Python API for document conversion and processing utilities.

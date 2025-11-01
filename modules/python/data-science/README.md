# data_science (Python)

**Purpose:** Tools for data science.

## Install
```bash
pip install -e ./modules/python/data-science
```

## Usage

### Command Line
```bash
data-science example
data-science example --option
```

### Python API
```python
from data_science import cli
cli.app()
```

## Examples
See the `examples/` directory for complete usage examples.

## Tested Versions
- Python: 3.9–3.12

## Notes

**Status:** 🔨 Stub Module (Planned for Implementation)

This module is currently a stub (placeholder) with example commands. It is planned for future implementation.

### Planned Implementation

This module is intended to house CLI commands converted from the following scripts (as categorized in [`topic_map.md`](../../../topic_map.md)):

- `datasets.py` - Contains utilities for dataset optimization and conversion for ML workflows
- `etl_focused.py` - ETL (Extract, Transform, Load) utilities for data processing pipelines
- `modeling_focused.py` - Machine learning modeling utilities and helper functions

These scripts are located in:
- `python/` - Original working scripts
- `snippets/python/` - Preserved copies

When implemented, this module will provide reusable CLI commands and Python API for data science operations including dataset processing, ETL workflows, and ML modeling utilities.
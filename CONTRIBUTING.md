# Contributing Guidelines

Thank you for your interest in contributing to this snippets repository! This document outlines how to add new snippets, create modules, and maintain code quality.

## Adding a New Snippet

### 1. Add the Raw Snippet

Place your raw snippet in the appropriate language directory under `/snippets/<lang>/` with a descriptive filename and header:

```powershell
# PowerShell example
# Topic: system-admin
# Summary: Manages Windows services for a specific application
# Author: Your Name

# Your PowerShell code here...
```

```python
#!/usr/bin/env python3
"""
Topic: data-science
Summary: Processes CSV files for machine learning workflows
Author: Your Name
"""

# Your Python code here...
```

### 2. Open an Issue

Create an issue using the "Snippet to Module" template to track the conversion process.

### 3. Follow the Snippet → Module Checklist

- [ ] Identify topic; create `/modules/<lang>/<topic>/` if it doesn't exist
- [ ] Wrap into function/CLI with usage & help documentation
- [ ] Add tests (smoke test + 1 functional test if feasible)
- [ ] Add examples demonstrating usage
- [ ] Write module `README.md` (purpose, install, usage, examples, tested versions)
- [ ] Ensure proper exports (PowerShell `Export-ModuleMember`, Python CLI commands)
- [ ] Pass linters and style checks
- [ ] Update docs index with new module/functions

## Module Development Standards

### PowerShell Modules

```powershell
# Function template
function Verb-Noun {
<#
.SYNOPSIS
One-line summary of what the function does.

.DESCRIPTION
Detailed description of the function's behavior and purpose.

.PARAMETER ParamName
Description of each parameter.

.EXAMPLE
Verb-Noun -ParamName "value"
Description of what this example does.

.NOTES
Author: Your Name
Prerequisites: PowerShell 5.1+
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ParamName
    )
    
    # Implementation here
}

Export-ModuleMember -Function Verb-Noun
```

### Python Modules

```python
import typer

app = typer.Typer(add_completion=False)

@app.command()
def command_name(
    param: str = typer.Option(..., help="Description of parameter")
):
    """
    One-line description of the command.
    
    Detailed description if needed.
    """
    # Implementation here

if __name__ == "__main__":
    app()
```

### Zsh Plugins

```bash
# function_name - description of what it does
# usage: function_name [args]

function_name() {
    local param1="$1"
    # Implementation here
}
```

### Command Prompt Scripts

```cmd
@echo off
if "%~1"=="--help" goto :help

REM Main functionality here
goto :eof

:help
echo Usage: %~n0 [options]
echo.
echo Description of what the script does.
exit /b 0
```

## Testing Requirements

### PowerShell
- Use Pester for testing
- Include at least one smoke test per function
- Test parameter validation where applicable

```powershell
# Example test
Describe "ModuleName Tests" {
    BeforeAll {
        Import-Module ./ModuleName.psd1 -Force
    }
    
    It "Should execute without errors" {
        { Invoke-Function } | Should -Not -Throw
    }
}
```

### Python
- Use pytest for testing
- Include CLI command tests using typer.testing
- Test both success and error cases

```python
from typer.testing import CliRunner
from module.cli import app

runner = CliRunner()

def test_command():
    result = runner.invoke(app, ["command"])
    assert result.exit_code == 0
```

### Shell
- Use bats for testing
- Test function existence and basic execution

```bash
@test "function exists" {
    type function_name
}

@test "function runs without error" {
    run function_name
    [ "$status" -eq 0 ]
}
```

## Code Quality Standards

### Linting
- **PowerShell**: PSScriptAnalyzer (Warning level)
- **Python**: Ruff + Black (line length 100)
- **Shell**: shellcheck

### Documentation
- Every function/command must have help documentation
- Include at least one usage example
- Document all parameters and return values

### Error Handling
- Use appropriate error handling for each language
- Provide meaningful error messages
- Log important operations where appropriate

## Pull Request Process

1. **Create Feature Branch**: Use descriptive branch names like `add-docker-management-tools`
2. **Follow Checklist**: Complete the snippet → module checklist
3. **Run Tests**: Ensure all tests pass locally
4. **Update Documentation**: Update README files and docs index
5. **Commit Messages**: Use clear, atomic commits:
   - `feat: add Docker container management tools`
   - `test: add unit tests for Docker utilities`
   - `docs: update index with Docker module`

## Topic Guidelines

### Choosing Topics
- Use existing topics when possible
- Create new topics for distinct functional areas
- Use kebab-case for topic names (`data-science`, `system-admin`)

### Topic Naming Conventions
- **Folders**: kebab-case (`data-science`)
- **Python packages**: snake_case (`data_science`)
- **PowerShell modules**: PascalCase (`DataScience`)

## Maintenance

### Updating Dependencies
- Keep CI actions up to date
- Update language-specific dependencies regularly
- Test compatibility with new language versions

### Quality Assurance
- Re-run tests periodically
- Update documentation for clarity
- Refactor code for better maintainability

## Getting Help

- Open an issue for questions about contributing
- Tag maintainers for review assistance
- Check existing modules for implementation patterns

## Code of Conduct

Please follow our [Code of Conduct](CODE_OF_CONDUCT.md) in all interactions.
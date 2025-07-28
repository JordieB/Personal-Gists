<#
.SYNOPSIS
    Creates a basic data science project scaffold with directories, files, and a pyproject.toml.

.DESCRIPTION
    This function sets up a new data science project. It will:
    1. Create a README.md with the specified project slug.
    2. Create a LICENSE file (GPL-3.0) from GitHub's licenses API.
    3. Create a main project directory (named for the slug) with:
       - A models/ directory
       - __init__.py, config.py, logger.py
    4. Create data directories: data/raw, data/checkpoints, data/clean
    5. Create a figures directory
    6. Create a pyproject.toml, replacing {proj_slug} with the specified slug
    7. Create a .gitignore file using the provided template
    8. Optionally run Poetry commands to finalize setup
    9. Initialize a Git repository
    10. Create a .env file
    11. Create a main.ipynb notebook.

.PARAMETER proj_slug
    The project name/slug to use for directories and references within files. Must be a valid Python package name.

.EXAMPLE
    Create-DSProject -proj_slug "ds_optcg"

    Creates a new project named "ds_optcg" in the current folder, setting up:
    README.md, LICENSE, pyproject.toml, .gitignore,
    an empty .env, main.ipynb, 
    and the folder structure with sample config and logger files.

.NOTES
    Author: Jordie Belle
    Prerequisites: PowerShell V5 or higher
    Requirements:
    - Internet connection for downloading LICENSE from GitHub API
    - Write permissions in the current directory
    - Optional: Poetry for Python dependency management
    - Optional: Git for version control initialization
    
    Important Notes:
    - Ensure you're in the directory where you want these files created before calling this function
    - The script writes into the current path and will overwrite existing files
    - Project slug should follow Python package naming conventions (lowercase, underscores allowed)
    - Generated project includes data science best practices and structure
#>

function Create-DSProject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[a-z][a-z0-9_]*$')]
        [ValidateLength(1, 50)]
        [string]$proj_slug
    )

    try {
        Write-Information "Creating DS project for '$proj_slug'..." -InformationAction Continue

        # 1. Create README.md with H1
        try {
            $readmeContent = "# $proj_slug`n"
            Set-Content -Path "./README.md" -Value $readmeContent -Force -ErrorAction Stop
            Write-Information "Created: README.md" -InformationAction Continue
        } catch {
            Write-Error "Failed to create README.md: $($_.Exception.Message)"
            throw
        }

        # 2. Create LICENSE file using https://api.github.com/licenses/gpl-3.0
        try {
            $licenseResponse = Invoke-WebRequest -Uri "https://api.github.com/licenses/gpl-3.0" -ErrorAction Stop
            $licenseContent = ($licenseResponse | ConvertFrom-Json).body
            Set-Content -Path "./LICENSE" -Value $licenseContent -Force -ErrorAction Stop
            Write-Information "Created: LICENSE" -InformationAction Continue
        } catch {
            Write-Warning "Failed to download LICENSE from GitHub API: $($_.Exception.Message)"
            Write-Information "Creating basic GPL-3.0 LICENSE placeholder..." -InformationAction Continue
            Set-Content -Path "./LICENSE" -Value "GPL-3.0 License - Please update with full license text" -Force
        }

        # 3. Create the main project directory with a "models" subdirectory,
        #    and files "__init__.py", "config.py", "logger.py"
        try {
            New-Item -ItemType Directory -Path "./$proj_slug" -Force -ErrorAction Stop | Out-Null
            New-Item -ItemType Directory -Path "./$proj_slug/models" -Force -ErrorAction Stop | Out-Null

            # __init__.py
            $initPy = @"
from $proj_slug import config  # noqa: F401
# Example use later: from config import PROJ_ROOT
"@
            Set-Content -Path "./$proj_slug/__init__.py" -Value $initPy -Force -ErrorAction Stop

            # config.py
            $configPy = @"
import os
from pathlib import Path

from dotenv import load_dotenv
from loguru import logger

# Load environment variables from .env file if it exists
load_dotenv()

# Get the project root directory (parent of the directory containing this file)
PROJ_ROOT = Path(__file__).resolve().parent.parent

# Data directories
DATA_DIR = PROJ_ROOT / "data"
RAW_DATA_DIR = DATA_DIR / "raw"
CLEAN_DATA_DIR = DATA_DIR / "clean"
CHECKPOINTS_DIR = DATA_DIR / "checkpoints"

# Figures directory
FIGURES_DIR = PROJ_ROOT / "figures"

# Ensure directories exist
for directory in [DATA_DIR, RAW_DATA_DIR, CLEAN_DATA_DIR, CHECKPOINTS_DIR, FIGURES_DIR]:
    directory.mkdir(parents=True, exist_ok=True)

# Logging configuration
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
LOG_FORMAT = ("{time:YYYY-MM-DD HH:mm:ss} | {level} | {name}:{function}:{line} | "
              "{message}")

# Configure loguru
logger.remove()  # Remove default handler
logger.add(
    PROJ_ROOT / "logs" / f"$proj_slug.log",
    rotation="1 day",
    retention="30 days",
    level=LOG_LEVEL,
    format=LOG_FORMAT
)
logger.add(
    lambda msg: print(msg, end=""),
    level=LOG_LEVEL,
    format=LOG_FORMAT,
    colorize=True
)

# Example configuration variables
RANDOM_SEED = int(os.getenv("RANDOM_SEED", 42))
DEBUG = os.getenv("DEBUG", "False").lower() in ("true", "1", "yes")

logger.info(f"Configuration loaded for project: $proj_slug")
logger.info(f"Project root: {PROJ_ROOT}")
logger.info(f"Data directory: {DATA_DIR}")
logger.info(f"Debug mode: {DEBUG}")
"@
            Set-Content -Path "./$proj_slug/config.py" -Value $configPy -Force -ErrorAction Stop

            # logger.py
            $loggerPy = @"
from loguru import logger
from $proj_slug.config import LOG_LEVEL, LOG_FORMAT, PROJ_ROOT

# This module provides a configured logger instance
# The logger is already configured in config.py, so we just import and use it

def get_logger(name: str = "$proj_slug"):
    """Get a logger instance with the specified name."""
    return logger.bind(name=name)

# Example usage:
# from $proj_slug.logger import get_logger
# logger = get_logger(__name__)
# logger.info("This is a log message")
"@
            Set-Content -Path "./$proj_slug/logger.py" -Value $loggerPy -Force -ErrorAction Stop

            Write-Information "Created: Directory '$proj_slug' plus __init__.py, config.py, logger.py" -InformationAction Continue
        } catch {
            Write-Error "Failed to create project directory structure: $($_.Exception.Message)"
            throw
        }

        # 4. Create data directories
        try {
            New-Item -ItemType Directory -Path "./data" -Force -ErrorAction Stop | Out-Null
            New-Item -ItemType Directory -Path "./data/raw" -Force -ErrorAction Stop | Out-Null
            New-Item -ItemType Directory -Path "./data/checkpoints" -Force -ErrorAction Stop | Out-Null
            New-Item -ItemType Directory -Path "./data/clean" -Force -ErrorAction Stop | Out-Null
            Write-Information "Created: data/, data/raw, data/checkpoints, data/clean" -InformationAction Continue
        } catch {
            Write-Error "Failed to create data directories: $($_.Exception.Message)"
            throw
        }

        # 5. Create figures directory
        try {
            New-Item -ItemType Directory -Path "./figures" -Force -ErrorAction Stop | Out-Null
            Write-Information "Created: figures/" -InformationAction Continue
        } catch {
            Write-Error "Failed to create figures directory: $($_.Exception.Message)"
            throw
        }

        # 6. Create pyproject.toml
        try {
            $pyprojectToml = @"
[tool.poetry]
name = "$proj_slug"
version = "0.1.0"
description = "Data science project: $proj_slug"
authors = ["Your Name <your.email@example.com>"]
license = "GPL-3.0"
readme = "README.md"
packages = [{include = "$proj_slug"}]

[tool.poetry.dependencies]
python = "^3.9"
pandas = "^2.0.0"
numpy = "^1.24.0"
matplotlib = "^3.7.0"
seaborn = "^0.12.0"
scikit-learn = "^1.3.0"
jupyter = "^1.0.0"
ipykernel = "^6.25.0"
loguru = "^0.7.0"
python-dotenv = "^1.0.0"
plotly = "^5.15.0"

[tool.poetry.group.dev.dependencies]
pytest = "^7.4.0"
black = "^23.7.0"
flake8 = "^6.0.0"
mypy = "^1.5.0"
isort = "^5.12.0"
pre-commit = "^3.3.0"

[tool.poetry.group.docs.dependencies]
sphinx = "^7.1.0"
sphinx-rtd-theme = "^1.3.0"

[build-system]
requires = ["poetry-core"]
build-backend = "poetry.core.masonry.api"

[tool.black]
line-length = 88
target-version = ['py39']
include = '\.pyi?$'
extend-exclude = '''
/(
  # directories
  \.eggs
  | \.git
  | \.hg
  | \.mypy_cache
  | \.tox
  | \.venv
  | build
  | dist
)/
'''

[tool.isort]
profile = "black"
multi_line_output = 3
line_length = 88
include_trailing_comma = true
force_grid_wrap = 0
use_parentheses = true
ensure_newline_before_comments = true

[tool.mypy]
python_version = "3.9"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true
disallow_incomplete_defs = true
check_untyped_defs = true
disallow_untyped_decorators = true
no_implicit_optional = true
warn_redundant_casts = true
warn_unused_ignores = true
warn_no_return = true
warn_unreachable = true
strict_equality = true

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py", "*_test.py"]
python_classes = ["Test*"]
python_functions = ["test_*"]
addopts = "-v --tb=short"

[tool.coverage.run]
source = ["$proj_slug"]
omit = ["*/tests/*", "*/__init__.py"]

[tool.coverage.report]
exclude_lines = [
    "pragma: no cover",
    "def __repr__",
    "if self.debug:",
    "if settings.DEBUG",
    "raise AssertionError",
    "raise NotImplementedError",
    "if 0:",
    "if __name__ == .__main__.:",
]
"@
            Set-Content -Path "./pyproject.toml" -Value $pyprojectToml -Force -ErrorAction Stop
            Write-Information "Created: pyproject.toml" -InformationAction Continue
        } catch {
            Write-Error "Failed to create pyproject.toml: $($_.Exception.Message)"
            throw
        }

        # 7. Create .gitignore
        try {
            $gitignoreContent = @"
# Byte-compiled / optimized / DLL files
__pycache__/
*.py[cod]
*$py.class

# C extensions
*.so

# Distribution / packaging
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
pip-wheel-metadata/
share/python-wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# PyInstaller
#  Usually these files are written by a python script from a template
#  before PyInstaller builds the exe, so as to inject date/other infos into it.
*.manifest
*.spec

# Installer logs
pip-log.txt
pip-delete-this-directory.txt

# Unit test / coverage reports
htmlcov/
.tox/
.nox/
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
*.py,cover
.hypothesis/
.pytest_cache/

# Translations
*.mo
*.pot

# Django stuff:
*.log
local_settings.py
db.sqlite3
db.sqlite3-journal

# Flask stuff:
instance/
.webassets-cache

# Scrapy stuff:
.scrapy

# Sphinx documentation
docs/_build/

# PyBuilder
target/

# Jupyter Notebook
.ipynb_checkpoints

# IPython
profile_default/
ipython_config.py

# pyenv
.python-version

# pipenv
#   According to pypa/pipenv#598, it is recommended to include Pipfile.lock in version control.
#   However, in case of collaboration, if having platform-specific dependencies or dependencies
#   having no cross-platform support, pipenv may install dependencies that don't work, or not
#   install all needed dependencies.
#Pipfile.lock

# PEP 582; used by e.g. github.com/David-OConnor/pyflow
__pypackages__/

# Celery stuff
celerybeat-schedule
celerybeat.pid

# SageMath parsed files
*.sage.py

# Environments
.env
.venv
env/
venv/
ENV/
env.bak/
venv.bak/

# Spyder project settings
.spyderproject
.spyproject

# Rope project settings
.ropeproject

# mkdocs documentation
/site

# mypy
.mypy_cache/
.dmypy.json
dmypy.json

# Pyre type checker
.pyre/

# Data science specific
data/raw/*
!data/raw/.gitkeep
data/processed/*
!data/processed/.gitkeep
data/interim/*
!data/interim/.gitkeep
data/external/*
!data/external/.gitkeep

# Model artifacts
models/*.pkl
models/*.joblib
models/*.h5
models/*.pt
models/*.pth

# Logs
logs/
*.log

# Jupyter notebook checkpoints
.ipynb_checkpoints/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Project specific
experiments/
temp/
tmp/
"@
            Set-Content -Path "./.gitignore" -Value $gitignoreContent -Force -ErrorAction Stop
            Write-Information "Created: .gitignore" -InformationAction Continue
        } catch {
            Write-Error "Failed to create .gitignore: $($_.Exception.Message)"
            throw
        }

        # 8. Create .env file
        try {
            $envContent = @"
# Environment variables for $proj_slug

# Logging
LOG_LEVEL=INFO
DEBUG=False

# Random seed for reproducibility
RANDOM_SEED=42

# Add your environment-specific variables here
# DATABASE_URL=
# API_KEY=
# SECRET_KEY=
"@
            Set-Content -Path "./.env" -Value $envContent -Force -ErrorAction Stop
            Write-Information "Created: .env" -InformationAction Continue
        } catch {
            Write-Error "Failed to create .env file: $($_.Exception.Message)"
            throw
        }

        # 9. Create main.ipynb
        try {
            $mainNotebook = @"
{
  "cells": [
    {
      "cell_type": "markdown",
      "id": "project-title",
      "metadata": {},
      "source": [
        "# $proj_slug\n",
        "\n",
        "Main analysis notebook for the $proj_slug project."
      ]
    },
    {
      "cell_type": "code",
      "execution_count": null,
      "id": "imports",
      "metadata": {},
      "outputs": [],
      "source": [
        "# Standard library imports\n",
        "import os\n",
        "import sys\n",
        "from pathlib import Path\n",
        "\n",
        "# Third-party imports\n",
        "import pandas as pd\n",
        "import numpy as np\n",
        "import matplotlib.pyplot as plt\n",
        "import seaborn as sns\n",
        "from loguru import logger\n",
        "\n",
        "# Project imports\n",
        "from $proj_slug.config import (\n",
        "    DATA_DIR,\n",
        "    RAW_DATA_DIR,\n",
        "    CLEAN_DATA_DIR,\n",
        "    FIGURES_DIR,\n",
        "    RANDOM_SEED,\n",
        "    DEBUG\n",
        ")\n",
        "from $proj_slug.logger import get_logger\n",
        "\n",
        "# Configure plotting\n",
        "plt.style.use('seaborn-v0_8')\n",
        "sns.set_palette('husl')\n",
        "\n",
        "# Set random seeds for reproducibility\n",
        "np.random.seed(RANDOM_SEED)\n",
        "\n",
        "# Get logger\n",
        "logger = get_logger(__name__)\n",
        "logger.info('Notebook initialized successfully')"
      ]
    },
    {
      "cell_type": "markdown",
      "id": "data-loading",
      "metadata": {},
      "source": [
        "## Data Loading and Exploration"
      ]
    },
    {
      "cell_type": "code",
      "execution_count": null,
      "metadata": {},
      "outputs": [],
      "source": [
        "# Load your data here\n",
        "# Example:\n",
        "# df = pd.read_csv(RAW_DATA_DIR / 'your_data.csv')\n",
        "# logger.info(f'Loaded data with shape: {df.shape}')"
      ]
    },
    {
      "cell_type": "markdown",
      "id": "analysis",
      "metadata": {},
      "source": [
        "## Analysis"
      ]
    },
    {
      "cell_type": "code",
      "execution_count": null,
      "metadata": {},
      "outputs": [],
      "source": [
        "# Your analysis code here"
      ]
    }
  ],
  "metadata": {
    "kernelspec": {
      "display_name": "Python 3",
      "language": "python",
      "name": "python3"
    },
    "language_info": {
      "codemirror_mode": {
        "name": "ipython",
        "version": 3
      },
      "file_extension": ".py",
      "mimetype": "text/x-python",
      "name": "python",
      "nbconvert_exporter": "python",
      "pygments_lexer": "ipython3",
      "version": "3.9.0"
    }
  },
  "nbformat": 4,
  "nbformat_minor": 5
}
"@
            Set-Content -Path "./main.ipynb" -Value $mainNotebook -Force -ErrorAction Stop
            Write-Information "Created: main.ipynb" -InformationAction Continue
        } catch {
            Write-Error "Failed to create main.ipynb: $($_.Exception.Message)"
            throw
        }

        # 10. Create logs directory
        try {
            New-Item -ItemType Directory -Path "./logs" -Force -ErrorAction Stop | Out-Null
            Write-Information "Created: logs/" -InformationAction Continue
        } catch {
            Write-Warning "Failed to create logs directory: $($_.Exception.Message)"
        }

        Write-Information "`nSuccess! Your data science skeleton for '$proj_slug' is set up." -InformationAction Continue
        Write-Information "Next steps:" -InformationAction Continue
        Write-Information "1. Run 'poetry install' to install dependencies" -InformationAction Continue
        Write-Information "2. Run 'git init' to initialize version control" -InformationAction Continue
        Write-Information "3. Update the .env file with your specific configuration" -InformationAction Continue
        Write-Information "4. Start coding in main.ipynb or create new scripts in the $proj_slug/ directory" -InformationAction Continue

        return $true

    } catch {
        Write-Error "Failed to create data science project: $($_.Exception.Message)"
        return $false
    }
}

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
    The project name/slug to use for directories and references within files.

.EXAMPLE
    Create-DSProject -proj_slug "ds_optcg"

    Creates a new project named "ds_optcg" in the current folder, setting up:
    README.md, LICENSE, pyproject.toml, .gitignore,
    an empty .env, main.ipynb, 
    and the folder structure with sample config and logger files.

.NOTES
    Ensure you're in the directory where you want these files created
    before calling this function, as the script writes into the current path.
#>

function Create-DSProject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$proj_slug
    )

    Write-Host "Creating DS project for '$proj_slug'..."

    # 1. Create README.md with H1
    $readmeContent = "# $proj_slug`n"
    Set-Content -Path "./README.md" -Value $readmeContent -Force
    Write-Host "Created: README.md"

    # 2. Create LICENSE file using https://api.github.com/licenses/gpl-3.0
    Invoke-WebRequest -Uri "https://api.github.com/licenses/gpl-3.0" |
        ConvertFrom-Json |
        Select-Object -ExpandProperty body |
        Set-Content -Path "./LICENSE" -Force
    Write-Host "Created: LICENSE"

    # 3. Create the main project directory with a "models" subdirectory,
    #    and files "__init__.py", "config.py", "logger.py"
    New-Item -ItemType Directory -Path "./$proj_slug" -Force | Out-Null
    New-Item -ItemType Directory -Path "./$proj_slug/models" -Force | Out-Null

    # __init__.py
    $initPy = @"
from $proj_slug import config  # noqa: F401
# Example use later: from config import PROJ_ROOT
"@
    Set-Content -Path "./$proj_slug/__init__.py" -Value $initPy -Force

    # config.py
    $configPy = @"
import os
from pathlib import Path

from dotenv import load_dotenv
from loguru import logger

# Load environment variables from .env file if it exists
load_dotenv()

# Paths and constants
PROJ_ROOT = Path(__file__).resolve().parents[1]
logger.info(f"PROJ_ROOT path is: {PROJ_ROOT}")

DATA_DIR = PROJ_ROOT / "data"
RAW_DATA_DIR = DATA_DIR / "raw"
INTERIM_DATA_DIR = DATA_DIR / "checkpoints"
PROCESSED_DATA_DIR = DATA_DIR / "clean"
MODELS_DIR = PROJ_ROOT / "models"
REPORTS_DIR = PROJ_ROOT / "reports"
FIGURES_DIR = REPORTS_DIR / "figures"

# Retrieve env variables for API and log if missing
API_KEY = os.getenv("API_KEY")
if not API_KEY:
    logger.warning("Missing API key")
"@
    Set-Content -Path "./$proj_slug/config.py" -Value $configPy -Force

    # logger.py
    $loggerPy = @"
import sys
from loguru import logger

# Clear any existing loggers to avoid duplication
logger.remove()

# Define a common log format
LOG_FORMAT = ("{time:YYYY-MM-DD HH:mm:ss} | {level} | {name}:{function}:{line} | "
              "{message}")

# Configure console logging
logger.add(
    sys.stderr,
    level="INFO",
    format=LOG_FORMAT,
    enqueue=True,       # Ensures thread-safe logging in multi-threaded environments
    backtrace=True,     # Displays full tracebacks for exceptions
    diagnose=True,      # Adds detailed information for debugging (use cautiously in production)
)

# Configure file logging
logger.add(
    "app.log",
    rotation="10 MB",   # Automatically rotates the log file when it reaches 10 MB
    retention="7 days", # Retains log files for 7 days
    compression="zip",  # Compresses old log files to save space
    format=LOG_FORMAT,
    level="DEBUG",
    enqueue=True,
    backtrace=True,
    diagnose=True,
)

# Export the logger instance for use in other modules
__all__ = ["logger"]
"@
    Set-Content -Path "./$proj_slug/logger.py" -Value $loggerPy -Force

    Write-Host "Created: Directory '$proj_slug' plus __init__.py, config.py, logger.py"

    # 4. Create data directories
    New-Item -ItemType Directory -Path "./data" -Force | Out-Null
    New-Item -ItemType Directory -Path "./data/raw" -Force | Out-Null
    New-Item -ItemType Directory -Path "./data/checkpoints" -Force | Out-Null
    New-Item -ItemType Directory -Path "./data/clean" -Force | Out-Null
    Write-Host "Created: data/, data/raw, data/checkpoints, data/clean"

    # 5. Create figures directory
    New-Item -ItemType Directory -Path "./figures" -Force | Out-Null
    Write-Host "Created: figures/"

    # 6. Create pyproject.toml with replacements
    $pyprojectToml = @"
[tool.poetry]
name = "{proj_slug}"
version = "0.1.0"
description = ""
authors = ["Jordie Belle <hello.jordie.belle@gmail.com>"]
license = "GPL-3.0-or-later"
readme = "README.md"
packages = [{include = "{proj_slug}"}]
classifiers = [
    "Programming Language :: Python :: 3",
]

[tool.poetry.dependencies]
python = "^3.11"
requests = "^2.32.3"
python-dotenv = "^1.0.1"
pandas = "^2.2.3"
ipykernel = "^6.29.5"
pyarrow = "^18.1.0"
pyperclip = "^1.9.0"
seaborn = "^0.13.2"
loguru = "^0.7.3"
httpx = "^0.28.1"
tenacity = "^9.0.0"

[tool.poetry.group.dev.dependencies]
isort = "^5.13.2"
flake8 = "^7.1.1"
flake8-pyproject = "^1.2.3"
bandit = "^1.8.0"
pip-audit = "^2.7.3"
pytest = "^8.3.4"
mypy = "^1.13.0"
pydantic = "^2.10.3"
black = {version = "^24.10.0", extras = ["juypter"]}

[tool.black]
line-length = 88
target-version = ["py311"]
include = "\\.pyi?$"
exclude = '''
    /(
        \.git
      | \.venv
      | __pycache__
      | old
      | build
      | dist
      | .mypy_cache
      | data
    )/
'''

[tool.isort]
profile = "black"
skip = [
    ".git",
    "__pycache__",
    "old",
    "build",
    "dist",
    ".venv",
    ".mypy_cache"
]

[tool.flake8]
ignore = [
    "E203",
    "E501",
    "W503"
]
max-line-length = 88
exclude = [
    ".venv/"
]

[tool.mypy]
mypy_path = "{proj_slug}"

[tool.bandit]
exclude_dirs = [
    ".git",
    "__pycache__",
    "old",
    "build",
    "dist",
    ".venv",
    ".mypy_cache",
    "external_protobufs"
]

[tool.pytest]
addopts = "--ignore=.mypy_cache --ignore=.venv --ignore=__pycache__ --ignore=.git"

[tool.poetry.scripts]
build = "{proj_slug}.build:main"
tasks = "{proj_slug}.tasks:main"

[build-system]
requires = ["poetry-core"]
build-backend = "poetry.core.masonry.api"
"@
    $pyprojectToml = $pyprojectToml -replace "\{proj_slug\}", $proj_slug
    Set-Content -Path "./pyproject.toml" -Value $pyprojectToml -Force
    Write-Host "Created: pyproject.toml"

    # 7. Create .gitignore
    $gitignoreContent = @"
# Unbranched/uncommited WIP files
_dev/
# Data
# Ignore all files/data within data dir
data/*
# Do not ignore subdirectory structure within data dir
!data/*/

# Mac OS-specific storage files
.DS_Store

# vim
*.swp
*.swo

## https://github.com/github/gitignore/blob/4488915eec0b3a45b5c63ead28f286819c0917de/Python.gitignore

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
share/python-wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# PyInstaller
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
cover/

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

# MkDocs documentation
docs/site/

# PyBuilder
.pybuilder/
target/

# Jupyter Notebook
.ipynb_checkpoints

# IPython
profile_default/
ipython_config.py

# pyenv
#.python-version

# pipenv
#Pipfile.lock

# poetry
#poetry.lock

# pdm
.pdm.toml
.pdm-python
.pdm-build/

# PEP 582
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

# pytype static type analyzer
.pytype/

# Cython debug symbols
cython_debug/

# PyCharm
#.idea/
"@
    Set-Content -Path "./.gitignore" -Value $gitignoreContent -Force
    Write-Host "Created: .gitignore"

    # 8. Run poetry set-up commands (optional; comment out if not desired)
    poetry lock
    poetry install
    poetry update

    # 9. Initialize empty git repo
    git init

    # 10. Create .env file (initially empty, modify as needed)
    $envFile = @"
# Example environment variables
# API_KEY=my_secret_api_key
"@
    Set-Content -Path "./.env" -Value $envFile -Force
    Write-Host "Created: .env"

    # 11. Create main.ipynb with a single Python code cell
    $mainNotebook = @"
{
  "cells": [
    {
      "cell_type": "code",
      "execution_count": null,
      "metadata": {},
      "outputs": [],
      "source": [
        "from $proj_slug.config import DATA_DIR"
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
      "name": "python"
    }
  },
  "nbformat": 4,
  "nbformat_minor": 5
}
"@
    # Replace {proj_slug} in the notebook source if desired (or you can just embed it directly above)
    $mainNotebook = $mainNotebook -replace "\$proj_slug", $proj_slug
    Set-Content -Path "./main.ipynb" -Value $mainNotebook -Force
    Write-Host "Created: main.ipynb"

    Write-Host "`nSuccess! Your data science skeleton for '$proj_slug' is set up."
}

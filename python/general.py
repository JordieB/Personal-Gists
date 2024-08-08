from os import stat
from json import load, dump, JSONDecodeError
from pathlib import Path as PlPath
from re import sub
from typing import Optional
from subprocess import run, check_output
from os import stat
from json import load, dump, JSONDecodeError
from pathlib import Path as PlPath


def get_current_path() -> PlPath:
    """
    Get the current path of the script or notebook.

    Returns:
        PlPath: The current directory path of the script or notebook.
    """
    try:
        # Attempt to use __file__, for .py run
        return PlPath(__file__).resolve().parent
    except NameError:
        # Fallback for .ipynb run
        return PlPath().absolute()

def find_project_root(current_path: Optional[PlPath] = None,
                      marker: str = ".git") -> PlPath:
    """
    Traverse upwards from the current path until a directory with the 
    specified marker is found, which indicates the root of the project.

    Args:
        current_path (Optional[PlPath], optional): The starting directory 
            path. If None, it will try to use the script's directory or the 
            current working directory. Defaults to None.
        marker (str): A filename or directory name that marks the root. 
                      Defaults to '.git'.

    Returns:
        PlPath: The root directory of the project.

    Raises:
        FileNotFoundError: If no directory with the specified marker is found.

    Example:
        root_dir = find_project_root()
        print(f"Project Root: {root_dir}")
    """
    if current_path is None:
        current_path = get_current_path()

    # Search current directory and then parents
    for path in [current_path] + list(current_path.parents):
        if (path / marker).exists():
            return path
    raise FileNotFoundError(
        f"Unable to find the root directory. No '{marker}' found."
    )

def camel_to_snake(name: str) -> str:
    """
    Convert a camel case string to snake case.

    Args:
        name (str): The camel case string.

    Returns:
        str: The snake case converted string.

    Example:
        snake_name = camel_to_snake("CamelCaseString")
        print(snake_name)  # Output: camel_case_string
    """
    s1 = sub("(.)([A-Z][a-z]+)", r"\1_\2", name)
    return sub("([a-z0-9])([A-Z])", r"\1_\2", s1).lower()

def ensure_makefile_and_env() -> None:
    """
    Ensures a Makefile with specific commands and a .env file with defined 
    variables exist, and appends necessary configurations to settings.json 
    in the .vscode directory.

    This function performs the following steps:
    1. Creates or updates a Makefile with specified targets.
    2. Creates or updates an .env file with PROJ_ROOT and PYTHONPATH
       variables.
    3. Creates or updates .vscode/settings.json with python.envFile
       configuration.
    4. Adds a __init__.py file in the current working directory with the
       specified import.

    Example:
        ensure_makefile_and_env()

    This will:
    - Create or update a Makefile with 'env', 'vsc_workspace_settings',
      'requirements', 'clean', 'lint', 'format', and 'init_py' commands.
    - Create or update an .env file with PROJ_ROOT and PYTHONPATH variables.
    - Create or update .vscode/settings.json with python.envFile configuration.
    - Add an __init__.py file in the current working directory with 'from src 
      import config  # noqa: F401'.
    """
    # Paths and file names
    cwd = PlPath.cwd()
    makefile_path = cwd / "Makefile"
    env_file_path = cwd / ".env"
    vscode_settings_path = cwd / ".vscode" / "settings.json"
    init_file_path = cwd / "__init__.py"

    # Makefile content
    makefile_content = f"""
env:
\t@echo "Creating .env file if it does not exist and adding PROJ_ROOT and PYTHONPATH"
\t@if [ ! -f .env ]; then echo "PROJ_ROOT={cwd}" > .env; fi
\t@if ! grep -q '^PROJ_ROOT' .env; then echo "PROJ_ROOT={cwd}" >> .env; fi
\t@if ! grep -q '^PYTHONPATH' .env; then echo "PYTHONPATH=$(pwd)" >> .env; fi

vsc_workspace_settings:
\t@echo "Ensuring .vscode/settings.json contains python.envFile"
\t@mkdir -p .vscode
\t@touch .vscode/settings.json
\t@python -c "from json import load, dump; import os.path as osp; \
        p = '.vscode/settings.json'; \
        s = load(open(p)) if osp.exists(p) and osp.stat(p).st_size > 0 else {{}}; \
        s['python.envFile'] = '${{workspaceFolder}}/.env'; \
        dump(s, open(p, 'w'), indent=4)"

requirements: env vsc_workspace_settings
\t@poetry config virtualenvs.in-project true
\t@poetry install
\t@poetry config --unset virtualenvs.in-project

clean:
\t@echo "Removing all compiled Python files"
\t@find . -name '*.pyc' -delete
\t@find . -name '__pycache__' -delete

lint:
\t@echo "Linting the code with flake8"
\t@flake8 .

format:
\t@echo "Formatting the code with black"
\t@black .

init_py:
\t@echo "Adding __init__.py with 'from src import config  # noqa: F401'"
\t@echo "from src import config  # noqa: F401" > __init__.py
    """.strip()

    # Ensure Makefile exists and contains the necessary commands
    if not makefile_path.exists() or not makefile_path.is_file():
        makefile_path.write_text(makefile_content)
    else:
        existing_content = makefile_path.read_text()
        if "env:" not in existing_content:
            makefile_path.write_text(existing_content + "\n" + makefile_content)

    # Ensure .env file exists and contains PROJ_ROOT and PYTHONPATH
    if not env_file_path.exists():
        env_file_path.write_text(f"PROJ_ROOT={cwd}\nPYTHONPATH={cwd}\n")
    else:
        with env_file_path.open("r+") as env_file:
            lines = env_file.readlines()
            proj_root_defined = any(line.startswith("PROJ_ROOT=") for line in lines)
            pythonpath_defined = any(line.startswith("PYTHONPATH=") for line in lines)
            if not proj_root_defined:
                env_file.write(f"PROJ_ROOT={cwd}\n")
            if not pythonpath_defined:
                env_file.write(f"PYTHONPATH={cwd}\n")

    # Ensure .vscode/settings.json exists and contains the necessary configuration
    vscode_settings_path.parent.mkdir(exist_ok=True)
    if vscode_settings_path.exists() and stat(vscode_settings_path).st_size > 0:
        with vscode_settings_path.open("r+") as settings_file:
            try:
                settings = load(settings_file)
            except JSONDecodeError:
                settings = {}
    else:
        settings = {}

    settings["python.envFile"] = "${workspaceFolder}/.env"

    with vscode_settings_path.open("w") as settings_file:
        dump(settings, settings_file, indent=4)

    # Ensure __init__.py exists with the specified import statement
    init_file_path.write_text("from src import config  # noqa: F401\n")

    # Save current Poetry configuration for virtualenvs.in-project
    original_venv_setting = check_output(
        ["poetry", "config", "virtualenvs.in-project"], universal_newlines=True
    ).strip()

    # Run the requirements target and restore original Poetry configuration
    try:
        run(["make", "requirements"], check=True)
    finally:
        if original_venv_setting:
            run(
                ["poetry", "config", "virtualenvs.in-project", original_venv_setting]
            )
        else:
            run(["poetry", "config", "--unset", "virtualenvs.in-project"])

from sys import path as sys_path
from os import stat, environ
from pathlib import Path as PlPath
from re import sub
from typing import Optional
from subprocess import run, check_output
from os import stat
from json import (
    load as json_load,
    dump as json_dump,
    JSONDecodeError
)

from dotenv import load_dotenv


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
                settings = json_load(settings_file)
            except JSONDecodeError:
                settings = {}
    else:
        settings = {}

    settings["python.envFile"] = "${workspaceFolder}/.env"

    with vscode_settings_path.open("w") as settings_file:
        json_dump(settings, settings_file, indent=4)

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

def update_path(new_path):
    """
    Updates the VS Code workspace settings.json to include a new path in 
    'python.analysis.extraPaths' and appends the new path to sys.path.

    This function ensures that the provided `new_path` is added to the 
    'python.analysis.extraPaths' list in the VS Code settings.json file, 
    which is located in the .vscode directory at the project root. 
    Additionally, it adds the `new_path` to the Python sys.path if it 
    isn't already present.

    Args:
        new_path (str): The new path to be added to the VS Code settings 
        and sys.path.

    Raises:
        EnvironmentError: If the PROJ_ROOT environment variable is not set.
        JSONDecodeError: If the settings.json file contains invalid JSON.

    Example:
        To add a path to the VS Code settings and sys.path, you can use the
        function as follows:

        ```python
        from os import environ

        # Ensure PROJ_ROOT environment variable is set
        environ['PROJ_ROOT'] = '/path/to/project/root'

        # Call the function with the new path
        new_path = '/path/to/add'
        update_path(new_path)
        ```
    """

    # Load environment variables
    load_dotenv()

    # Retrieve project root from environment variable
    proj_root = environ.get('PROJ_ROOT')
    if not proj_root:
        raise EnvironmentError("PROJ_ROOT environment variable is not set.")

    proj_root = PlPath(proj_root)
    settings_fp = proj_root / '.vscode' / 'settings.json'

    # Ensure .vscode directory and settings.json file exist
    settings_fp.parent.mkdir(parents=True, exist_ok=True)
    if not settings_fp.exists():
        settings_fp.write_text('{}')

    # Load current settings from settings.json
    try:
        with settings_fp.open('r', encoding='utf-8') as file:
            settings = json_load(file)
    except JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in settings.json: {e.msg}")

    # Update extraPaths in settings
    extra_paths = settings.get('python.analysis.extraPaths', [])
    if new_path not in extra_paths:
        extra_paths.append(new_path)
        settings['python.analysis.extraPaths'] = extra_paths

        # Write updated settings back to settings.json
        with settings_fp.open('w', encoding='utf-8') as file:
            json_dump(settings, file, ensure_ascii=False, indent=4)

    # Add new path to sys.path if not already present
    if new_path not in sys_path:
        sys_path.append(new_path)

def display_entire_pd_obj_with_float_format():
    import pandas as pd
    import numpy as np

    # Create dataframe with random data for example
    np.random.seed(0)
    df = pd.DataFrame({
        'float_col': np.random.rand(10) * 100  # Random float values
    })

    # Set display options for float format
    with pd.option_context('display.float_format', lambda x: ('%.17f' % x).rstrip('0').rstrip('.')):
        # Display the description of the float_col
        print(df['float_col'].describe().to_frame())

def density_histo_with_rug_plot():
    """
    This type of plot can help you quickly identify where the outliers are
    in a long tail histo via rug plot
    """
    import matplotlib.pyplot as plt
    import seaborn as sns
    import numpy as np

    # Create random data with a long tail
    np.random.seed(42)
    data = np.concatenate([np.random.normal(loc=50, scale=10, size=1000), np.random.normal(loc=150, scale=20, size=200)])

    # Create a histogram with density and a rug plot
    plt.figure(figsize=(12, 6))
    sns.histplot(data, bins=30, stat='density', kde=True, color='skyblue', edgecolor='black')
    sns.rugplot(data, height=0.05, color='red')

    # Add titles and labels
    plt.title('Histogram with Density and Rug Plot')
    plt.xlabel('Value')
    plt.ylabel('Density')

    # Show the plot
    plt.show()

def using_subplot_mosiacs():
    import pandas as pd
    import numpy as np
    import matplotlib.pyplot as plt
    import seaborn as sns

    # Step 1: Generate data
    np.random.seed(42)  # For reproducibility

    # Create a new dataframe with 1000 rows
    n_rows = 1000
    df = pd.DataFrame({
        'id': np.arange(1, n_rows + 1),
        'category': np.random.choice(['Category_A', 'Category_B', 'Category_C'], size=n_rows),
        'value': np.random.uniform(0, 100, size=n_rows)
    })

    # Step 2: Create fig_design to define the subplot mosaic
    fig_design = [['Category_A'], ['Category_B'], ['Category_C']]

    # Step 3 & 4: Create a plt figure with constrained layout and subplot mosaic
    fig, ax_dict = plt.subplot_mosaic(fig_design, constrained_layout=True, figsize=(8, 12))

    # Step 5: Iterate over unique values of category
    for category in df['category'].unique():
        # Filter df by the matching category value
        filtered_data = df[df['category'] == category]

        # Remove outliers using IQR
        Q1, Q3 = filtered_data['value'].quantile([0.25, 0.75])
        IQR = Q3 - Q1
        non_outlier_data = filtered_data[
            (filtered_data['value'] >= Q1 - 1.5 * IQR) &
            (filtered_data['value'] <= Q3 + 1.5 * IQR)
        ]

        # Plot using seaborn histplot
        sns.histplot(non_outlier_data['value'], bins=20, ax=ax_dict[category])

        # Set title and labels
        ax_dict[category].set_title(f"Histogram for {category}", color='#e5b567')
        ax_dict[category].set_xlabel("Value")

        # Format x-axis values as integers
        ax_dict[category].xaxis.set_major_formatter(plt.FuncFormatter(lambda x, _: f"{int(x)}"))

    # Step 6: Set a supertitle for the figure
    fig.suptitle("Distribution of Values by Category", fontsize=16)

    plt.show()

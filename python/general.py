from pathlib import Path


def get_current_path():
    try:
        # Attempt to use __file__, for .py run
        return Path(__file__).resolve().parent
    except NameError:
        # Fallback for .ipynb run
        return Path().absolute()

def find_project_root(current_path: Path = None, marker: str = '.git') -> Path:
    """
    Traverse upwards from the current path until a directory with the specified
    marker is found, which indicates the root of the project.

    Args:
        current_path (Path, optional): The starting directory path. If None, it
                                       will try to use the script's directory
                                       or the current working directory.
                                       Defaults to None.
        marker (str): A filename or directory name that marks the root. 
                      Defaults to '.git'.

    Returns:
        Path: The root directory of the project.

    Example usage:
        root_dir = find_project_root()
        print(f"Project Root: {root_dir}")
    """
    
    if current_path is None:
        current_path = get_current_path()
    
    for parent in current_path.parents:
        if (parent / marker).exists():
            return parent
    raise FileNotFoundError((f"Unable to find the root directory. No "
                             f"'{marker}' found."))

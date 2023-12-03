from pathlib import Path


def find_project_root(current_path: Path, marker: str = '.git') -> Path:
    """
    Traverse upwards from the current path until a directory with the specified
    marker is found, which indicates the root of the project.

    Args:
        current_path (Path): The starting directory path.
        marker (str): A filename or directory name that marks the root. 
                      Defaults to '.git'.

    Returns:
        Path: The root directory of the project.
    """
    for parent in current_path.parents:
        if (parent / marker).exists():
            return parent
    raise FileNotFoundError((f"Unable to find the root directory. No "
                             f"'{marker}' found."))

import pytest
from typer.testing import CliRunner
from data_science.cli import app

runner = CliRunner()

def test_example_command():
    """Test the example command."""
    result = runner.invoke(app, ["example"])
    assert result.exit_code == 0
    assert "data science" in result.stdout

def test_example_command_with_option():
    """Test the example command with option."""
    result = runner.invoke(app, ["example", "--option"])
    assert result.exit_code == 0
    assert "option" in result.stdout

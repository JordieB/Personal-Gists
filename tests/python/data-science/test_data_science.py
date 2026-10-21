import pytest
from typer.testing import CliRunner
from data_science.cli import app

runner = CliRunner()

@pytest.mark.parametrize(
    ("arguments", "expected"),
    [(["example"], "data science"), (["example", "--option"], "option")],
)
def test_example_command(arguments, expected):
    result = runner.invoke(app, arguments)
    assert result.exit_code == 0
    assert expected in result.stdout

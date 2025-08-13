import typer

app = typer.Typer(add_completion=False)

@app.command()
def example(option: bool = False):
    """
    Example command for dev tools operations.
    """
    if option:
        print(f"Example dev tools command with option")
    else:
        print(f"Example dev tools command")

if __name__ == "__main__":
    app()

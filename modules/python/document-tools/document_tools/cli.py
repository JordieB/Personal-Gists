import typer

app = typer.Typer(add_completion=False)

@app.command()
def example(option: bool = False):
    """
    Example command for document tools operations.
    """
    if option:
        print("Example document tools command with option")
    else:
        print("Example document tools command")

if __name__ == "__main__":
    app()

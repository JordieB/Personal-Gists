import typer

app = typer.Typer(add_completion=False)

@app.command()
def example(option: bool = False):
    """
    Example command for data science operations.
    """
    if option:
        print(f"Example data science command with option")
    else:
        print(f"Example data science command")

if __name__ == "__main__":
    app()

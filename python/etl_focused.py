from typing import List
from json import dumps
from zipfile import ZipFile
from pathlib import Path
from warnings import warn

from pandas import DataFrame, read_csv
from requests.compat import urlencode
from kaggle.api.kaggle_api_extended import KaggleApi


def checkpoint_df(df: DataFrame, cols_to_serialize: List[str],
                  parquet_fn: str):
    """
    Serializes specified columns of a DataFrame and saves it as a Parquet file.

    This function takes a DataFrame, serializes the specified columns using
    JSON, and then saves the modified DataFrame to a Parquet file in the 'data'
    directory.

    Args:
        df: A pandas DataFrame to be serialized and saved.
        cols_to_serialize: A list of column names in the DataFrame to
            serialize.
        parquet_fn: Filename for the saved Parquet file, saved in 'data'
            directory.

    Example:
        df = pd.DataFrame(json_data)
        checkpoint_df(df, ['response'], 'swa_games_raw_json_pd_df.parquet')
    """
    # Creating a copy of the DataFrame to preserve the original
    to_save_df = df.copy()

    # Serializing specified columns
    for col in cols_to_serialize:
        # Apply JSON dumps to each column needing serialization
        to_save_df[col] = to_save_df[col].apply(dumps)

    # Saving the DataFrame to a Parquet file
    to_save_df.to_parquet(f'data/{parquet_fn}')

def convert_tsv_to_csv(tsv_txt: str, file_path: str):
    """
    Converts TSV (Tab-Separated Values) text to CSV (Comma-Separated Values) 
    format and writes the output to a file. City names in the data are enclosed
    in quotation marks.

    Args:
        tsv_txt (str): The TSV data as a string.
        file_path (str): The path where the CSV output will be saved.

    Example:
        tsv_data = "id\tcity\n1\tNew York\n2\tLos Angeles"
        file_path = 'data/cities.csv'
        convert_tsv_to_csv(tsv_data, file_path)
    """
    # Splitting the TSV data into rows and converting each row to CSV format
    csv_rows = [
        ','.join([item if idx != 1 else f'"{item}"'
                  for idx, item in enumerate(row.split("\t"))])
                  for row in tsv_txt.split("\n")
    ]

    # Joining the rows to form the CSV data
    csv_txt = "\n".join(csv_rows)

    # Writing the CSV data to the specified file
    with open(file_path, 'w') as file:
        file.write(csv_txt)

def load_google_sheet_as_df(
    spreadsheet_id: str, 
    sheet_name: str
) -> DataFrame:
    """
    Loads a specific sheet from a Google Sheets spreadsheet as a Pandas
        DataFrame.

    Args:
        spreadsheet_id (str): The unique identifier for the Google Sheets
            spreadsheet.
        sheet_name (str): The name of the sheet to load.

    Returns:
        DataFrame: A DataFrame containing the data from the specified Google
            Sheets sheet.

    Example:
        spreadsheet_id = 'your_spreadsheet_id_here'
        sheet_name = 'your_sheet_name_here'
        df = load_google_sheet_as_df(spreadsheet_id, sheet_name)
    """
    # URL-encode the sheet name and create the URL
    encoded_params = urlencode({'sheet': sheet_name})
    base_url = 'https://docs.google.com/spreadsheets/d/'
    url = f'{base_url}{spreadsheet_id}/gviz/tq?tqx=out:csv&{encoded_params}'

    # Load the sheet into a Pandas DataFrame
    return read_csv(url)


def download_and_prepare_kaggle_data(competition_name: str = None,
                                     raw_data_dir: Path = None) -> None:
    """
    Downloads competition data from Kaggle, moves it to the specified data
    directory, and unzips the data.

    This function performs the following steps:
    1. Downloads the dataset from the Kaggle competition.
    2. Moves the downloaded zip file to the raw_data_dir.
    3. Unzips the contents of the zip file into the raw_data_dir.

    Args:
        competition_name (str): The name of the Kaggle competition. If None,
            it uses the value from config.
        raw_data_dir (Path): The directory to save and unzip the data. If 
            None, it uses the value from config.

    Example:
        download_and_prepare_kaggle_data()

    This will:
    - Download the dataset from the specified Kaggle competition.
    - Move the downloaded zip file to the specified raw data directory.
    - Unzip the contents of the zip file into the specified raw data directory.
    """
    try:
        if competition_name is None or raw_data_dir is None:
            from config import (
                RAW_DATA_DIR as config_raw_data_dir,
                COMPETITION_NAME as config_competition_name
            )
            if competition_name is None:
                competition_name = config_competition_name
            if raw_data_dir is None:
                raw_data_dir = config_raw_data_dir
    except ImportError:
        warn(("Failed to import from config. Please provide "
                       "competition_name and raw_data_dir."))
        if competition_name is None or raw_data_dir is None:
            raise ValueError(("Both competition_name and raw_data_dir must be "
                              "provided if config import fails."))

    # Ensure raw_data_dir is a Path object
    raw_data_dir = Path(raw_data_dir)

    # Paths
    download_zip: str = f"{competition_name}.zip"
    destination_zip: Path = raw_data_dir / download_zip
    destination_dir: Path = raw_data_dir

    # Ensure the destination directory exists
    raw_data_dir.mkdir(parents=True, exist_ok=True)

    # Initialize Kaggle API
    api = KaggleApi()
    api.authenticate()

    # Download the dataset from Kaggle
    api.competition_download_file(
        competition_name,
        file_name=download_zip,
        path="."
    )

    # Move the downloaded file
    Path(download_zip).rename(destination_zip)

    # Unzip the file
    with ZipFile(destination_zip, "r") as zip_ref:
        zip_ref.extractall(destination_dir)

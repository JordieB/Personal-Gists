from typing import List
from json import dumps

from pandas import DataFrame, read_csv
from requests.compat import urlencode


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
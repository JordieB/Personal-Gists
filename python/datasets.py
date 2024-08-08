from re import sub
from typing import Union

from pandas import DataFrame, Series, to_numeric
from numpy import ndarray


def convert_and_optimize_to_numerics(
        df: Union[ndarray, Series, DataFrame]) -> DataFrame:
    """
    Converts data to optimized numeric dtypes for memory efficiency and ease of use
    for statistical learning models.
        * Numeric cols are downcasted to int unless precision loss then float
        * Strings are converted to categorical codes
        * Boolean cols are converted to binary

    Args:
        df [np.ndarray, pd.Series, pd.DataFrame]:
            The data to be converted into optimized numeric dtypes.

    Returns:
        DataFrame: A new DataFrame with optimized numeric dtypes.

    Example:
        df = convert_and_optimize_to_numerics(df)
    """
    # Ensure np.ndarray or pd.Series are made into pd.Dataframe
    if isinstance(df, ndarray):
        df = DataFrame(df)
    elif isinstance(df, Series):
        df = df.to_frame()
    
    # Creating a copy of the DataFrame to avoid modifying the original one
    new_df = df.copy(deep=True)

    # General first pass to guess nullable dtypes
    new_df = new_df.convert_dtypes()

    # Grab column names by base dtype
    string_cols = new_df.select_dtypes(include='string').columns
    boolean_cols = new_df.select_dtypes(include='boolean').columns

    # Convert boolean columns to binary
    for col in boolean_cols:
        new_df[col] = new_df[col].astype(int)

    # Convert string columns to categorical codes
    for col in string_cols:
        new_df[col] = new_df[col].astype('category').cat.codes

    # Downcast numeric columns
    numeric_cols = new_df.select_dtypes(include='number').columns
    def to_numeric_downcast(series):
        # First, try to convert the series to integers
        try:
            int_series = to_numeric(series, downcast='integer')
            
            # If the conversion doesn't change the data (no precision loss),
            # return the integer series
            if (int_series == to_numeric(series)).all():
                return int_series
        except ValueError:
            pass
        
        # If the conversion isn't appropriate (precision would be lost),
        # return the series as float
        return to_numeric(series, downcast='float')
    
    new_df[numeric_cols] = new_df[numeric_cols].apply(to_numeric_downcast)

    # Pass through guessing method to ensure use of new, nullably pd dtypes
    new_df = new_df.convert_dtypes()

    return new_df

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

# TODO: allow use of handling pd.Series?
# TODO: how to identify good candidates for spare dtypes?
# TODO: how to handle/avoid casting strings to high cardinality categorical?

from pandas import DataFrame, to_numeric

def naive_dtype_optimize(df: DataFrame) -> DataFrame:
    """
    Downcasts the numerical columns of a DataFrame to float types and converts
    string columns to categorical types for memory efficiency.

    Args:
        df (DataFrame): The pandas DataFrame to be downcast.

    Returns:
        DataFrame: A new DataFrame with downcasted numeric and categorical
            columns.

    Example:
        df_downcasted = naive_downcast(original_df)
    """
    # Creating a copy of the DataFrame to avoid modifying the original one
    new_df = df.copy(deep=True)

    # General first pass to guess nullable dtypes
    new_df = new_df.convert_dtypes()
    # Grab column names by base dtype
    numeric_cols = new_df.select_dtypes(include='number').columns
    string_cols = new_df.select_dtypes(include='string').columns

    # Downcast numeric columns
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

    # Convert string columns to categorical
    new_df[string_cols] = new_df[string_cols].astype('category')

    return new_df

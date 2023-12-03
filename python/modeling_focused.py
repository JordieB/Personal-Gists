from pandas import DataFrame, to_numeric

def naive_downcast(df: DataFrame) -> DataFrame:
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

    # Convert data types to best possible format
    new_df = new_df.convert_dtypes()

    # Downcast numeric columns to the most suitable float type
    numeric_cols = new_df.select_dtypes(include='number').columns
    new_df[numeric_cols] = new_df[numeric_cols].apply(
        lambda col: to_numeric(col, downcast='float')
    )

    # Convert string columns to categorical
    string_cols = new_df.select_dtypes(include='string').columns
    new_df[string_cols] = new_df[string_cols].astype('category')

    return new_df

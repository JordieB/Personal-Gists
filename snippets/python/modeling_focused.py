def naive_rfr_predict():
    import pandas as pd
    import sklearn as sk
    import joblib

    train = pd.read_csv('data/preprocessed_train.csv').convert_dtypes()

    target_col_name = train.columns[-1]
    X = train.drop(columns=target_col_name)
    y = train.loc[:, target_col_name]
    X_train, X_valid, y_train, y_valid = (
        sk.model_selection.train_test_split(
            X, y, test_size=0.33, random_state=42
        )
    )

    model = sk.ensemble.RandomForestRegressor()
    model.fit(X_train, y_train)
    valid_preds = model.predict(X_valid)

    print(sk.metrics.mean_absolute_error(y_valid, valid_preds))
    joblib.dump(model, 'model/naive_rfr.joblib')
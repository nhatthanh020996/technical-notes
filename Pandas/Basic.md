### Core objects and creation
````python
import pandas as pd

# Series (1D)
s = pd.Series([10, 20, 30], index=["a", "b", "c"])

# DataFrame (2D)
df = pd.DataFrame({
    "name": ["Alice", "Bob", "Cara", "Dan"],
    "age": [25, 31, 29, 40],
    "city": ["Hanoi", "HCMC", "Da Nang", "Hanoi"],
    "income": [15_000_000, 22_000_000, None, 18_500_000],
})
df.head()
````

### Inspecting data (always start here)
````python
df.head(3)      # first rows
df.tail(3)      # last rows
df.shape        # (rows, cols)
df.columns      # column names
df.dtypes       # data types
df.info()       # non-null counts + dtypes
df.describe(numeric_only=True)  # quick stats
````

### Selecting columns and renaming
````python
df["age"]                   # single column (Series)
df[["name", "city"]]        # multiple columns (DataFrame)

df = df.rename(columns={"income": "monthly_income"})
df["yearly_income"] = df["monthly_income"] * 12
df.head()
````

### Row/column selection: loc vs iloc
````python
# label-based
df.loc[0, "name"]                  # first row, 'name' col
df.loc[df["city"] == "Hanoi", ["name", "age"]]

# position-based
df.iloc[0, 0]                      # first row, first col
df.iloc[:2, :2]                    # first 2 rows, first 2 cols
````

### Filtering rows (boolean masks)
````python
adults = df[df["age"] >= 30]
hanoi_or_dn = df[df["city"].isin(["Hanoi", "Da Nang"])]
mid_income = df[df["monthly_income"].between(16_000_000, 20_000_000)]
````

### Sorting
````python
df.sort_values(by="age", ascending=False).head()
df.sort_values(by=["city", "age"], ascending=[True, False]).head()
````

### Missing values (NaN) — clean early
````python
df["monthly_income"].isna().sum()    # count missing
df_clean = df.copy()
df_clean["monthly_income"] = df_clean["monthly_income"].fillna(0)
# or drop rows with missing in specific columns
df_drop = df.dropna(subset=["monthly_income"])
````

### Type conversion and dates
````python
df["age"] = df["age"].astype("int32")
# Example date parsing
dates = pd.to_datetime(pd.Series(["2024-01-05", "2024/02/10", "Mar 3 2024"]))
dates.dt.year, dates.dt.month
````

### Transform Dataframe columns
#### 1. Vectorized (fast, preferred)
```python
filtered_df["area_num"] = pd.to_numeric(filtered_df["area"], errors="coerce")
filtered_df["pop_num"]  = pd.to_numeric(filtered_df["population"], errors="coerce")
filtered_df["density"]  = (filtered_df["pop_num"] / filtered_df["area_num"]).round(2)
```

#### 2. String vectorized
```python
filtered_df["commune_name_clean"] = (
    filtered_df["commune_name"].str.strip().str.replace(r"\s+", " ", regex=True).str.title()
)
```

#### 3. Series.map with function or dict (element-wise)
```python
def clean_name(s):
    return s.strip().title() if isinstance(s, str) else s
filtered_df["commune_name"] = filtered_df["commune_name"].map(clean_name)

prefix_map = {"Phường": "Ward", "Xã": "Commune", "Thị trấn": "Town"}
filtered_df["commune_prefix_en"] = filtered_df["commune_prefix"].map(prefix_map)
```

#### 4. Series.apply (element-wise; OK but slower than vectorized)
```python
filtered_df["name_len"] = filtered_df["commune_name"].apply(lambda s: len(s) if isinstance(s, str) else 0)
```

#### 5. DataFrame.apply across columns (needs multiple columns; slowest)
```python
filtered_df["full_name"] = filtered_df.apply(
    lambda r: f"{r['commune_prefix']} {r['commune_name']}", axis=1
)
```

#### Conditional transform (vectorized)
import numpy as np
filtered_df["is_city"] = np.where(filtered_df["province_prefix"] == "Thành phố", 1, 0).astype("int8")

### Groupby and basic aggregations (most-used)
````python
df.groupby("city")["monthly_income"].mean(numeric_only=True)
df.groupby("city").agg(
    avg_income=("monthly_income", "mean"),
    n=("name", "count"),
    max_age=("age", "max"),
)
````


### Read/write data
````python
# CSV
df.to_csv("people.csv", index=False)
df_csv = pd.read_csv("people.csv")

# Parquet (fast, typed)
df.to_parquet("people.parquet", index=False)
df_parq = pd.read_parquet("people.parquet")
````

11) Best practices (save time)
- Prefer vectorized ops over loops and apply.
- After filtering, assign with .loc to avoid SettingWithCopy warnings:
````python
df.loc[df["city"] == "Hanoi", "city_group"] = "north"
````

Quick practice using your current notebook’s df
````python
# You already have `df` from the JSON. Try:
df.head()
df.info()
df[["province_id", "commune_name"]].head()
df[df["population"] > 10_000].sort_values("population", ascending=False).head(10)
df.groupby("province_name")["population"].sum().sort_values(ascending=False).head(5)
````
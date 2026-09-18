# **Elasticsearch `bool` Query: `must`, `filter`, and `should` Clauses**

## **1. `must` Clause**
- **Purpose**: Defines conditions that **must** be satisfied for a document to match.
- **Behavior**:
  - Acts as a logical **AND** for all queries inside it.
  - A document must satisfy **all conditions** in the `must` clause to be included in the results.
- **Impact on Scoring**: Affects the relevance score of matching documents.
- **Use Case**: When you want strict matching criteria.

### **Example**:
```json
{
  "bool": {
    "must": [
      { "match": { "field1": "value1" } },
      { "term": { "field2": "value2" } }
    ]
  }
}
```
- **Explanation**: A document must match both `field1: value1` and `field2: value2`.

---

## **2. `filter` Clause**
- **Purpose**: Defines conditions that **must** be satisfied, but does not affect the relevance score.
- **Behavior**:
  - Acts as a logical **AND** for all queries inside it.
  - Filters documents based on criteria without scoring them.
  - More efficient than `must` for non-scoring queries.
- **Impact on Scoring**: Does **not** affect the relevance score.
- **Use Case**: When you want to filter results without influencing their scores.

### **Example**:
```json
{
  "bool": {
    "filter": [
      { "term": { "field1": "value1" } },
      { "range": { "field2": { "gte": 10 } } }
    ]
  }
}
```
- **Explanation**: Filters documents where `field1` is `value1` and `field2` is greater than or equal to `10`.

---

## **3. `should` Clause**
- **Purpose**: Defines conditions that **should** be satisfied to boost relevance scores.
- **Behavior**:
  - Acts as a logical **OR** for all queries inside it.
  - Documents that satisfy one or more `should` conditions receive a **higher score**.
  - If no `must` or `filter` clauses are present, at least **one `should` condition must match** (unless `minimum_should_match` is specified).
- **Impact on Scoring**: Boosts the relevance score of matching documents.
- **Use Case**: When you want to prioritize certain conditions but not enforce them.

### **Example**:
```json
{
  "bool": {
    "should": [
      { "match": { "field1": "value1" } },
      { "match": { "field2": "value2" } }
    ],
    "minimum_should_match": 1
  }
}
```
- **Explanation**: A document should match at least one of the conditions (`field1: value1` OR `field2: value2`).

---

## **4. Combining `must`, `filter`, and `should`**
- **`must`**: Defines mandatory conditions.
- **`filter`**: Filters documents without affecting scores.
- **`should`**: Boosts the relevance of documents that satisfy these conditions.

### **Example**:
```json
{
  "bool": {
    "must": [
      { "term": { "field1": "value1" } }
    ],
    "filter": [
      { "range": { "field2": { "gte": 10 } } }
    ],
    "should": [
      { "match": { "field3": "value3" } },
      { "match": { "field4": "value4" } }
    ],
    "minimum_should_match": 1
  }
}
```
- **Explanation**:
  - `must`: The document must match `field1: value1`.
  - `filter`: The document must have `field2 >= 10`.
  - `should`: The document should match at least one of `field3: value3` or `field4: value4` to boost its score.

---

## **5. Key Takeaways**
- **`must`**: Mandatory conditions (affects scoring).
- **`filter`**: Mandatory conditions (does not affect scoring).
- **`should`**: Optional conditions (boosts scoring).
- **`minimum_should_match`**: Specifies how many `should` conditions must match.
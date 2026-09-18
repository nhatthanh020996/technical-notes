# How Match Query Works in Elasticsearch

The `match` query is one of the most fundamental query types in Elasticsearch. It performs a full-text search on a specific field.

## How Match Query Works

1. **Analysis**: Elasticsearch analyzes the query text using the field's `search_analyzer`
2. **Term Creation**: The analyzer converts the query into individual terms
3. **Term Search**: Elasticsearch looks for documents containing these terms
4. **Scoring**: Documents are scored based on term frequency, inverse document frequency, and field length

## Example

Let's use a `match` query to search for places with "coffee shop" in their name:

```bash
curl --location --request POST 'http://localhost:9200/places/_search' \
--header 'Authorization: Basic ZWxhc3RpYzpwZzFRd3YmSEJFK0V5K2U/' \
--header 'Content-Type: application/json' \
--data '{
  "query": {
    "match": {
      "name": "coffee shop"
    }
  }
}'
```

### What Happens Behind the Scenes

1. **Analysis of Query**:
   - "coffee shop" is analyzed using the `search_analyzer` (defined for the `name` field)
   - The analyzer converts to lowercase and removes accents
   - Result: tokens ["coffee", "shop"]

2. **Document Matching**:
   - By default, documents matching ANY of the terms are returned (OR logic)
   - Documents containing both "coffee" and "shop" will score higher
   - Documents with just "coffee" or just "shop" will also be returned but with lower scores


## Basic Match Query Options

```json
{
  "query": {
    "match": {
      "name": {
        "query": "coffee shop",
        "operator": "and",
        "minimum_should_match": "75%",
        "fuzziness": "AUTO",
        "analyzer": "custom_analyzer",
        "boost": 2.0
      }
    }
  }
}
```

### Main Options Explained

1. **`operator`** - Controls how terms combine
   ```json
   "operator": "and"  // Possible values: "or" (default), "and"
   ```
   - `"or"`: Matches documents containing ANY of the terms (default)
   - `"and"`: Requires ALL terms to match

2. **`minimum_should_match`** - Specifies minimum percentage or number of terms that must match
   ```json
   "minimum_should_match": "75%"  // Can be percentage or absolute number
   ```
   - `"50%"`: At least half the terms must match
   - `"2"`: Exactly 2 terms must match

3. **`fuzziness`** - Allows for typo tolerance
   ```json
   "fuzziness": "AUTO"  // Can be "AUTO", 0, 1, 2
   ```
   - `"AUTO"`: Automatically determines edit distance based on term length
   
   - `2`: Maximum of 2 character changes allowed

4. **`analyzer`** - Override the field's `search_analyzer`
   ```json
   "analyzer": "standard"  // Uses specified analyzer instead of field's search_analyzer
   ```

5. **`boost`** - Increases the relevance score
   ```json
   "boost": 2.0  // Multiplies score by this value
   ```

## Examples with Your Configuration

### 1. Basic Match Query with Required Matching

```bash
curl --location --request POST 'http://localhost:9200/places/_search' \
--header 'Authorization: Basic ZWxhc3RpYzpwZzFRd3YmSEJFK0V5K2U/' \
--header 'Content-Type: application/json' \
--data '{
  "query": {
    "match": {
      "name": {
        "query": "highlands coffee",
        "operator": "and"
      }
    }
  }
}'
```
*This requires both "highlands" AND "coffee" to appear in the name field*

### 2. Fuzzy Matching for Typo Tolerance

```bash
curl --location --request POST 'http://localhost:9200/places/_search' \
--header 'Authorization: Basic ZWxhc3RpYzpwZzFRd3YmSEJFK0V5K2U/' \
--header 'Content-Type: application/json' \
--data '{
  "query": {
    "match": {
      "name": {
        "query": "coffe shop",
        "fuzziness": "AUTO"
      }
    }
  }
}'
```
*This will match "coffee shop" even though "coffee" is misspelled as "coffe"*

### 3. Partial Term Matching with minimum_should_match

```bash
curl --location --request POST 'http://localhost:9200/places/_search' \
--header 'Authorization: Basic ZWxhc3RpYzpwZzFRd3YmSEJFK0V5K2U/' \
--header 'Content-Type: application/json' \
--data '{
  "query": {
    "match": {
      "name": {
        "query": "highlands coffee shop restaurant",
        "minimum_should_match": "50%"
      }
    }
  }
}'
```
*This requires at least 2 of the 4 terms to match*

### 4. Boosting the Relevance Score

```bash
curl --location --request POST 'http://localhost:9200/places/_search' \
--header 'Authorization: Basic ZWxhc3RpYzpwZzFRd3YmSEJFK0V5K2U/' \
--header 'Content-Type: application/json' \
--data '{
  "query": {
    "bool": {
      "should": [
        {
          "match": {
            "name": {
              "query": "coffee",
              "boost": 3.0
            }
          }
        },
        {
          "match": {
            "description": "coffee"
          }
        }
      ]
    }
  }
}'
```
*This makes matches in the "name" field 3 times more important than matches in "description"*

### 5. Using a Different Analyzer

```bash
curl --location --request POST 'http://localhost:9200/places/_search' \
--header 'Authorization: Basic ZWxhc3RpYzpwZzFRd3YmSEJFK0V5K2U/' \
--header 'Content-Type: application/json' \
--data '{
  "query": {
    "match": {
      "name": {
        "query": "coffee shop",
        "analyzer": "standard"
      }
    }
  }
}'
```
*This overrides your configured "search_analyzer" with the standard analyzer*

The `match` query is versatile and by using these options effectively with your custom `search_analyzer`, you can fine-tune the search behavior to match your specific requirements.
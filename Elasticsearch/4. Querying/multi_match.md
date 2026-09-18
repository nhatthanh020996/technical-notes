# Understanding `multi_match` Query in Elasticsearch

The `multi_match` query is a versatile query type that allows you to run the same search query against multiple fields simultaneously. This is particularly useful for search interfaces where a single search box needs to match content across different parts of your documents.

## How multi_match Works

`multi_match` applies the same query text to multiple fields, with the ability to control:
- Which fields to search
- How to combine the scores from different fields
- Different matching strategies

## Basic Example

```bash
curl --location --request POST 'http://localhost:9200/places/_search' \
--header 'Authorization: Basic ZWxhc3RpYzpwZzFRd3YmSEJFK0V5K2U/' \
--header 'Content-Type: application/json' \
--data '{
  "query": {
    "multi_match": {
      "query": "highlands coffee",
      "fields": ["name", "description", "short_name"]
    }
  }
}'
```

This searches for "highlands coffee" in the name, description, and short_name fields.

## Field Boosting

You can boost certain fields to make them more important:

```json
{
  "query": {
    "multi_match": {
      "query": "highlands coffee",
      "fields": ["name^3", "description", "short_name^2"]
    }
  }
}
```

This makes matches in the `name` field 3x more important and `short_name` 2x more important than `description`.

## Multi_match Types

The `multi_match` query supports different types that control matching behavior:

### 1. best_fields (default)

Finds documents where any field matches, using the score from the best matching field:

```json
{
  "query": {
    "multi_match": {
      "query": "highlands coffee",
      "fields": ["name", "description"],
      "type": "best_fields",
      "tie_breaker": 0.3
    }
  }
}
```

- Uses highest score by default
- With `tie_breaker`, adds a fraction of the other scores
- Good for finding the single most relevant field match

### 2. most_fields

Combines scores from all matching fields:

```json
{
  "query": {
    "multi_match": {
      "query": "highlands coffee",
      "fields": ["name", "description", "short_name"],
      "type": "most_fields"
    }
  }
}
```

- Sums scores from all matching fields
- Good when multiple field matches indicate higher relevance

### 3. cross_fields

Treats terms as if they were in a single big field:

```json
{
  "query": {
    "multi_match": {
      "query": "highlands coffee",
      "fields": ["name", "short_name"],
      "type": "cross_fields",
      "operator": "and"
    }
  }
}
```

- Searches for each term across all fields
- Good for fields that contain parts of the same entity (like first_name/last_name)
- Works well with your `search_analyzer` configuration

### 4. phrase

Runs a `match_phrase` query on each field:

```json
{
  "query": {
    "multi_match": {
      "query": "highlands coffee",
      "fields": ["name", "description"],
      "type": "phrase",
      "slop": 2
    }
  }
}
```

- Requires terms to appear in order (with optional slop)
- Good for exact phrase matching across fields

### 5. phrase_prefix

Runs a `match_phrase_prefix` query on each field:

```json
{
  "query": {
    "multi_match": {
      "query": "high coff",
      "fields": ["name", "short_name"],
      "type": "phrase_prefix",
      "max_expansions": 10
    }
  }
}
```

- Like phrase but with prefix matching on the last term
- Excellent for autocomplete across multiple fields

## Real-World Example for Place Search

For a complete place search that works well with your mapping:

```bash
curl --location --request POST 'http://localhost:9200/places/_search' \
--header 'Authorization: Basic ZWxhc3RpYzpwZzFRd3YmSEJFK0V5K2U/' \
--header 'Content-Type: application/json' \
--data '{
  "query": {
    "multi_match": {
      "query": "high cof",
      "type": "cross_fields",
      "fields": [
        "name^3",
        "short_name^2",
        "description",
        "sublabel"
      ],
      "operator": "and"
    }
  },
  "sort": [
    "_score",
    { "popularity_score": "desc" }
  ]
}'
```

This query:
- Searches across 4 fields with different importance weights
- Uses cross_fields to find terms across all fields
- Requires all terms to match somewhere (with `operator: "and"`)
- Sorts by relevance first, then by popularity

The `multi_match` query is extremely flexible and works well with your existing mapping configuration, especially with the custom `search_analyzer` you've defined.
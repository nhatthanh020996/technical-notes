# Basic Query Types in Elasticsearch

Elasticsearch provides various query types to search and filter your data. Here's a comprehensive overview of the most commonly used query types:

## Match Query

The standard full-text query for performing full-text search.

```json
{
  "query": {
    "match": {
      "name": "highlands coffee"
    }
  }
}
```

## Match Phrase Query

Match exact phrases in text fields.

```json
{
  "query": {
    "match_phrase": {
      "name": "highlands coffee"
    }
  }
}
```

## Term Query

Exact matching on structured data (not analyzed).

```json
{
  "query": {
    "term": {
      "type": "cafe"
    }
  }
}
```

## Terms Query

Match if field contains any of the specified terms.

```json
{
  "query": {
    "terms": {
      "category": ["cafe", "restaurant", "bakery"]
    }
  }
}
```

## Range Query

Find documents with field values within a specified range.

```json
{
  "query": {
    "range": {
      "price_level": {
        "gte": 1,
        "lte": 3
      }
    }
  }
}
```

## Bool Query

Combine multiple queries with boolean logic.

```json
{
  "query": {
    "bool": {
      "must": [
        { "match": { "name": "coffee" } }
      ],
      "filter": [
        { "term": { "verified": true } }
      ],
      "should": [
        { "match": { "description": "premium" } }
      ],
      "must_not": [
        { "term": { "price_level": 4 } }
      ]
    }
  }
}
```

## Exists Query

Find documents where a specific field exists.

```json
{
  "query": {
    "exists": {
      "field": "website"
    }
  }
}
```

## Prefix Query

Match documents containing terms with a specified prefix.

```json
{
  "query": {
    "prefix": {
      "name.keyword": "High"
    }
  }
}
```

## Wildcard Query

Match documents containing terms matching a wildcard pattern.

```json
{
  "query": {
    "wildcard": {
      "name.keyword": "High*Coffee"
    }
  }
}
```

## Fuzzy Query

Match terms with some edit distance (typo tolerance).

```json
{
  "query": {
    "fuzzy": {
      "name": {
        "value": "coffe",
        "fuzziness": "AUTO"
      }
    }
  }
}
```

## Multi-match Query

Run the same query against multiple fields.

```json
{
  "query": {
    "multi_match": {
      "query": "coffee shop",
      "fields": ["name", "description", "short_name"]
    }
  }
}
```

## Query String Query

Supports Lucene query string syntax.

```json
{
  "query": {
    "query_string": {
      "default_field": "name",
      "query": "coffee AND shop"
    }
  }
}
```

## Nested Query

Query on nested objects.

```json
{
  "query": {
    "nested": {
      "path": "business_hours",
      "query": {
        "bool": {
          "must": [
            { "term": { "business_hours.day": "monday" } },
            { "range": { "business_hours.open": { "lte": "08:00" } } }
          ]
        }
      }
    }
  }
}
```

## Geo Distance Query

Find locations within a certain distance.

```json
{
  "query": {
    "geo_distance": {
      "distance": "5km",
      "coordinate": {
        "lat": 10.7765,
        "lon": 106.7012
      }
    }
  }
}
```

## Ids Query

Fetch documents by their IDs.

```json
{
  "query": {
    "ids": {
      "values": ["1", "2", "3"]
    }
  }
}
```

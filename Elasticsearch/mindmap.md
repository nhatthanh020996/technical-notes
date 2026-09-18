Elasticsearch
│
├── Core Concepts
│   ├── Documents
│   │   ├── JSON-based data units
│   │   ├── Uniquely identified
│   │   └── Self-contained
│   │
│   ├── Indices
│   │   ├── Collection of documents
│   │   ├── Logical namespace
│   │   └── Sharding and replication
│   │
│   ├── Shards
│   │   ├── Primary shards
│   │   ├── Replica shards
│   │   └── Distribution across nodes
│   │
│   └── Nodes & Clusters
│       ├── Master nodes
│       ├── Data nodes
│       ├── Client nodes
│       └── Coordinating nodes
│
├── Mapping & Data Types
│   ├── Field Types
│   │   ├── Text & Keyword
│   │   ├── Numeric (long, integer, etc.)
│   │   ├── Date
│   │   ├── Boolean
│   │   ├── Geo (geo_point, geo_shape)
│   │   └── Specialized (completion, search_as_you_type)
│   │
│   ├── Mapping Parameters
│   │   ├── analyzer/search_analyzer
│   │   ├── index (true/false)
│   │   ├── doc_values
│   │   └── fields (multi-fields)
│   │
│   └── Dynamic vs. Explicit Mapping
│
├── Text Analysis
│   ├── Analyzers
│   │   ├── Built-in (standard, simple, etc.)
│   │   └── Custom analyzers
│   │
│   ├── Tokenizers
│   │   ├── Standard
│   │   ├── Whitespace
│   │   ├── Pattern
│   │   └── Keyword
│   │
│   ├── Token Filters
│   │   ├── lowercase
│   │   ├── stemming filters
│   │   ├── stop
│   │   ├── synonyms
│   │   ├── edge_ngram
│   │   └── shingle
│   │
│   └── Character Filters
│       ├── HTML strip
│       ├── Mapping
│       └── Pattern replace
│
├── Querying
│   ├── Full-text Queries
│   │   ├── match
│   │   ├── multi_match
│   │   ├── match_phrase
│   │   ├── match_phrase_prefix
│   │   └── query_string
│   │
│   ├── Term-level Queries
│   │   ├── term
│   │   ├── terms
│   │   ├── range
│   │   ├── exists
│   │   └── prefix
│   │
│   ├── Compound Queries
│   │   ├── bool (must, should, must_not, filter)
│   │   ├── dis_max
│   │   └── function_score
│   │
│   ├── Specialized Queries
│   │   ├── Geo queries
│   │   ├── Nested queries
│   │   └── Script queries
│   │
│   └── Relevance & Scoring
│       ├── TF/IDF
│       ├── BM25
│       ├── Boosting
│       └── Decay functions
│
├── Aggregations
│   ├── Bucket Aggregations
│   │   ├── Terms
│   │   ├── Date histogram
│   │   ├── Range
│   │   └── Geo distance
│   │
│   ├── Metric Aggregations
│   │   ├── Avg, min, max, sum
│   │   ├── Cardinality
│   │   └── Percentiles
│   │
│   └── Pipeline Aggregations
│       ├── Avg bucket
│       ├── Derivative
│       └── Moving average
│
├── Search Features
│   ├── Pagination
│   │   ├── From/size
│   │   ├── Search after
│   │   └── Scroll API
│   │
│   ├── Highlighting
│   ├── Suggestions
│   │   ├── Term suggester
│   │   ├── Phrase suggester
│   │   └── Completion suggester
│   │
│   └── Search Experience
│       ├── Autocomplete
│       ├── Did you mean
│       └── Faceted navigation
│
├── Operations & Administration
│   ├── Indexing Performance
│   │   ├── Bulk API
│   │   ├── Refresh interval
│   │   └── Indexing buffer size
│   │
│   ├── Monitoring
│   │   ├── Cluster health
│   │   ├── Node stats
│   │   └── Index stats
│   │
│   └── Maintenance
│       ├── Index aliases
│       ├── Reindexing
│       └── Snapshots & restore
│
└── Advanced Topics
    ├── Ingest Pipelines
    │   ├── Processors
    │   └── Pipeline configuration
    │
    ├── ILM (Index Lifecycle Management)
    │   ├── Hot-warm-cold architecture
    │   └── Rollover
    │
    ├── Security
    │   ├── Authentication
    │   ├── Authorization
    │   └── Encryption
    │
    └── Machine Learning
        ├── Anomaly detection
        └── Regression & classification
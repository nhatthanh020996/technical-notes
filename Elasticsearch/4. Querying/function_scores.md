# Complete Query Explanation with Elasticsearch Scoring Breakdown

Based on the actual `_explanation` results from Elasticsearch, here's how your query works:

---

## **Query Structure Overview**

````json
{
  "query": {
    "bool": {
      "must": [...]     // Required: Text matching
      "should": [...]   // Optional: Scoring boosts
      "filter": [...]   // Required: No scoring
    }
  }
}
````

**Score Combination:**
````javascript
final_score = must_score + should[0]_score + should[1]_score + 0 (filter) + 0 (filter)
            = text_score + geo_score + popularity_score
````

---

## **Phase 1: FILTER Clauses (Pre-screening)**

### **Purpose:** Eliminate documents before scoring (fast, cached)

````json
"filter": [
  {
    "terms": {
      "source": ["1", "2", "3", "4"]
    }
  },
  {
    "terms": {
      "layer": ["venue", "address", "street", "locality", "county", "region"]
    }
  }
]
````

**Parameters:**

| Parameter | Meaning | Your Values |
|-----------|---------|-------------|
| `terms` | Match if field value is in the list | Boolean OR condition |
| `source` | Data source identifier | 1=OSM, 2=?, 3=WOF, 4=CSV |
| `layer` | Type of geographic entity | venue, address, street, etc. |

**What happens:**
````javascript
// Step 1: Check source
if (doc.source NOT IN ["1", "2", "3", "4"]) {
  exclude();  // Document removed
}

// Step 2: Check layer
if (doc.layer NOT IN ["venue", "address", ...]) {
  exclude();  // Document removed
}

// Result: ~5.5M documents → ~50,000 candidates
````

**Score contribution:** `0.0` (filters don't score)

---

## **Phase 2: MUST Clause (Required Text Match)**

### **Purpose:** Find documents that match the search text

````json
"must": [
  {
    "multi_match": {
      "type": "phrase_prefix",
      "query": "đại học sư pham ky thuat",
      "fields": ["phrase.default"],
      "analyzer": "peliasQuery",
      "boost": 1,
      "slop": 4
    }
  }
]
````

### **Parameters Explained:**

| Parameter | Meaning | Your Value | Effect |
|-----------|---------|------------|--------|
| `type` | Matching algorithm | `"phrase_prefix"` | Match phrase, last word can be prefix |
| `query` | User's search text | `"đại học sư pham ky thuat"` | Input to analyze |
| `fields` | Fields to search in | `["phrase.default"]` | Search in the main phrase field |
| `analyzer` | Text processing pipeline | `"peliasQuery"` | Remove diacritics, lowercase, tokenize |
| `boost` | Score multiplier | `1` | No artificial boost |
| `slop` | Max word distance allowed | `4` | Allow up to 4 words between terms |

---

### **Text Analysis Process:**

````javascript
// Input
query = "đại học sư pham ky thuat"

// After peliasQuery analyzer:
// 1. Remove diacritics: đại → dai
// 2. Lowercase
// 3. Tokenize by spaces
tokens = ["dai", "hoc", "su", "pham", "ky", "thuat"]

// Elasticsearch also expands last term with synonyms/alternatives:
expanded = [
  "dai", "hoc", "su", "pham", "ky",
  "thuat", "thuat-noi", "thuat&in", "thuat-visa", ...  // 50+ variations
]
````

**Why so many variations?**
- Handles different spellings: "kỹ thuật" vs "ky thuat"
- Matches compound words: "kỹ-thuật", "kỹ&thuật"
- Covers abbreviations: "SPKT", "KT"
- Vietnamese language variations

---

### **Phrase Prefix Matching:**

````javascript
// Documents that match:

✅ "Đại Học Sư Phạm Kỹ Thuật"
   → ["dai", "hoc", "su", "pham", "ky", "thuat"]
   → Exact phrase match

✅ "Đại Học Sư Phạm Kỹ"
   → ["dai", "hoc", "su", "pham", "ky"]
   → Last word "ky" is prefix of "ky thuat"

✅ "Đại Học [A] [B] Sư Phạm Kỹ Thuật"
   → slop=4 allows 2 words gap

❌ "Sư Phạm Đại Học Kỹ Thuật"
   → Wrong word order (phrase match requires order)

❌ "Đại Học Công Nghiệp"
   → Different terms ("công nghiệp" ≠ "sư phạm")
````

---

### **BM25 Scoring Formula:**

From the `_explanation`:

````json
{
  "value": 699.9845,
  "description": "score(freq=1.0), computed as boost * idf * tf",
  "details": [
    {"value": 2.2, "description": "boost"},
    {"value": 762.62964, "description": "idf, sum of:"},
    {"value": 0.41720742, "description": "tf"}
  ]
}
````

**Formula:**
````javascript
score = boost × IDF × TF
````

---

### **Parameter 1: Boost (2.2)**

````javascript
// Boost = query boost × field boost × coordination factor
boost = 1.0 (query) × 1.0 (field) × 2.2 (internal)

// 2.2 comes from Elasticsearch's phrase matching bonus
// (rewards exact phrase matches over scattered terms)
````

**Meaning:** Phrase matches get 2.2× higher score than individual term matches.

---

### **Parameter 2: IDF (Inverse Document Frequency) - 762.63**

````javascript
// IDF measures term rarity (rare terms = higher score)

IDF_total = sum of IDF for each term

// For each term:
IDF = log(1 + (N - n + 0.5) / (n + 0.5))

// Where:
// N = Total documents in corpus = 5,573,044
// n = Documents containing this term
````

**Example calculations from your query:**

| Term | Documents (n) | IDF Calculation | IDF Value | Rarity |
|------|---------------|-----------------|-----------|--------|
| `dai` (đại) | 101,370 | log(1 + (5573044-101370+0.5)/(101370+0.5)) | 4.01 | Common |
| `hoc` (học) | 31,503 | log(1 + (5573044-31503+0.5)/(31503+0.5)) | 5.18 | Medium |
| `su` (sư) | 17,301 | log(1 + (5573044-17301+0.5)/(17301+0.5)) | 5.77 | Medium |
| `pham` (phạm) | 118,017 | log(1 + (5573044-118017+0.5)/(118017+0.5)) | 3.85 | Common |
| `ky` (kỹ) | 33,497 | log(1 + (5573044-33497+0.5)/(33497+0.5)) | 5.11 | Medium |
| `thuat` (thuật) | **1** | log(1 + (5573044-1+0.5)/(1+0.5)) | **15.13** | Very rare |
| `thuat-noi` | **1** | log(1 + ...) | **15.13** | Very rare |
| `thuat-visa` | **1** | log(1 + ...) | **15.13** | Very rare |
| ... | ... | ... | ... | ... |

**Total IDF:** 762.63 (sum of all term IDFs)

**Why so high?**
- Many rare compound variations of "thuật" (IDF=15.13 each)
- 50+ term variations from phrase expansion
- Rare terms dominate the score

---

### **Parameter 3: TF (Term Frequency) - 0.417**

````javascript
// TF measures how well the term appears in the document

TF = freq / (freq + k1 × (1 - b + b × dl / avgdl))

// Where:
freq = 1.0          // Phrase appears once in doc
k1 = 1.2            // Term saturation parameter (default)
b = 0.75            // Length normalization parameter (default)
dl = 6.0            // Document length (this doc has 6 tokens)
avgdl = 4.92        // Average document length in corpus
````

**Calculation:**
````javascript
TF = 1.0 / (1.0 + 1.2 × (1 - 0.75 + 0.75 × 6.0 / 4.92))
   = 1.0 / (1.0 + 1.2 × (0.25 + 0.75 × 1.22))
   = 1.0 / (1.0 + 1.2 × 1.165)
   = 1.0 / (1.0 + 1.398)
   = 1.0 / 2.398
   = 0.417
````

**Parameter meanings:**

| Parameter | Value | Meaning |
|-----------|-------|---------|
| `freq` | 1.0 | Phrase appears once |
| `k1` | 1.2 | Controls term saturation (higher k1 = more importance to frequency) |
| `b` | 0.75 | Controls length normalization (0=ignore length, 1=full normalization) |
| `dl` | 6.0 | This document has 6 words in phrase field |
| `avgdl` | 4.92 | Average field length across all documents |

**Why TF is 0.417 (not 1.0)?**
- Document is longer than average (6 vs 4.92 tokens)
- Length normalization (`b=0.75`) penalizes longer documents
- Prevents long documents from ranking higher just due to length

---

### **Final Text Score:**

````javascript
text_score = boost × IDF × TF
           = 2.2 × 762.63 × 0.417
           = 699.98
````

**This is your base relevance score.**

---

## **Phase 3: SHOULD Clause #1 (Geographic Boost)**

### **Purpose:** Boost nearby locations

````json
{
  "function_score": {
    "query": {"match_all": {}},
    "functions": [{
      "weight": 650,
      "exp": {
        "center_point": {
          "origin": {
            "lat": 10.849994739428553,
            "lon": 106.77281176333895
          },
          "offset": "0.5km",
          "scale": "5km",
          "decay": 0.1
        }
      }
    }],
    "score_mode": "avg",
    "boost_mode": "multiply"
  }
}
````

### **Parameters Explained:**

| Parameter | Meaning | Your Value | Effect |
|-----------|---------|------------|--------|
| `query` | Base query for this function | `{"match_all": {}}` | All documents get score=1.0 |
| `weight` | Multiplier for function result | `650` | Amplifies geographic effect |
| `exp` | Exponential decay function | ... | Distance-based scoring |
| `origin` | Reference point (user's location) | `(10.85°N, 106.77°E)` | Near HCMC, Vietnam |
| `offset` | Distance with full score | `"0.5km"` | Within 500m = 100% score |
| `scale` | Half-decay distance | `"5km"` | At 5.5km, score drops to 10% |
| `decay` | Score at (offset + scale) | `0.1` | At 5.5km, score = 0.1 |
| `score_mode` | How to combine multiple functions | `"avg"` | Average (only 1 function, so no effect) |
| `boost_mode` | How to combine with query score | `"multiply"` | Match_all(1.0) × decay × weight |

---

### **Exponential Decay Formula:**

````javascript
// Calculate distance from origin
distance = arcDistance(
  doc.center_point.lat, doc.center_point.lon,
  origin.lat, origin.lon
)

// Apply exponential decay
if (distance <= offset) {
  decay = 1.0  // Full score within offset
} else {
  // Exponential decay beyond offset
  decayFactor = -ln(decay_value) / scale
  decay = exp(- decayFactor × (distance - offset))
  decay = exp(- ln(0.1) / 5000m × (distance - 500m))
  decay = exp(- 0.0004605 × (distance - 500m))
}

// Function score
geo_score = match_all_score × decay × weight
          = 1.0 × decay × 650
````

---

### **Example: HCMC Document**

From `_explanation`:

````json
{
  "value": 650.0,
  "description": "function score, product of:",
  "details": [
    {"value": 1.0, "description": "*:*"},  // match_all
    {
      "value": 650.0,
      "description": "product of:",
      "details": [
        {
          "value": 1.0,
          "description": "exp(- MIN of: [Math.max(arcDistance(...) - 500.0(=offset), 0)] * 4.605170185988091E-4)"
        },
        {"value": 650.0, "description": "weight"}
      ]
    }
  ]
}
````

**Calculation:**
````javascript
// Document coordinates
doc_lat = 10.853339
doc_lon = 106.773285

// Calculate distance
distance = haversine(10.853339, 106.773285, 10.849995, 106.772812)
         = ~400m

// Apply decay
Math.max(distance - offset, 0) = Math.max(400 - 500, 0) = 0
decay = exp(- 0 × 0.0004605) = exp(0) = 1.0

// Geographic score
geo_score = 1.0 × 1.0 × 650 = 650.0
````

**Within 500m = full geographic bonus!**

---

### **Decay at Different Distances:**

| Distance | Distance - Offset | Calculation | Decay | Geo Score |
|----------|------------------|-------------|-------|-----------|
| **0m** | 0 | exp(0 × 0.0004605) | **1.0** | **650** |
| **500m** | 0 | exp(0 × 0.0004605) | **1.0** | **650** |
| **1km** | 500m | exp(-500 × 0.0004605) | **0.794** | **516** |
| **2km** | 1,500m | exp(-1500 × 0.0004605) | **0.501** | **326** |
| **3km** | 2,500m | exp(-2500 × 0.0004605) | **0.316** | **205** |
| **5.5km** | 5,000m | exp(-5000 × 0.0004605) | **0.1** | **65** |
| **10km** | 9,500m | exp(-9500 × 0.0004605) | **0.01** | **6.5** |
| **600km** | 599,500m | exp(-599500 × 0.0004605) | **~0** | **~0** |

**Visual decay curve:**

````
Score
650 |█████████████
    |█████████████  (within 500m)
500 |██████████
    |████████      (1-2km)
300 |█████
    |███          (3-5km)
100 |█
    |            (5-10km)
  0 |________________________________________
    0km   2km   4km   6km   8km   10km  →  distance
````

---

### **Understanding decay_value Parameter:**

````javascript
decay = 0.1  // At (offset + scale), score drops to 10%

// This means:
// At 0.5km + 5km = 5.5km → decay = 0.1 → score = 65 (10% of 650)

// To make decay more aggressive:
decay = 0.01  → At 5.5km, score = 6.5 (1% of 650)
decay = 0.001 → At 5.5km, score = 0.65 (0.1% of 650)
````

---

## **Phase 4: SHOULD Clause #2 (Popularity Boost)**

### **Purpose:** Boost popular/important places

````json
{
  "function_score": {
    "query": {"match_all": {}},
    "max_boost": 20,
    "functions": [{
      "field_value_factor": {
        "modifier": "log1p",
        "field": "popularity",
        "missing": 1
      },
      "weight": 1
    }],
    "score_mode": "first",
    "boost_mode": "multiply"
  }
}
````

### **Parameters Explained:**

| Parameter | Meaning | Your Value | Effect |
|-----------|---------|------------|--------|
| `query` | Base query | `{"match_all": {}}` | All documents get score=1.0 |
| `max_boost` | Maximum boost allowed | `20` | Caps popularity at 20× |
| `field` | Field to read value from | `"popularity"` | popularity field in document |
| `modifier` | Math function to apply | `"log1p"` | log₁₀(1 + value) |
| `missing` | Default if field absent | `1` | If no popularity, use 1 |
| `weight` | Function multiplier | `1` | No amplification |
| `score_mode` | Combine multiple functions | `"first"` | Use first function (only 1 here) |
| `boost_mode` | Combine with query score | `"multiply"` | match_all(1.0) × log(pop) × weight |

---

### **Logarithmic Scaling:**

````javascript
// Get popularity value
popularityValue = doc.popularity || 1  // Use 1 if missing

// Apply log1p (log base 10 of 1 + value)
popularity_factor = log₁₀(1 + popularityValue)

// Cap at max_boost
popularity_factor = min(popularity_factor, 20)

// Final score
pop_score = match_all_score × popularity_factor × weight
          = 1.0 × popularity_factor × 1
````

---

### **Why Logarithmic?**

````javascript
// Without log (linear):
popularity=10    → boost=10
popularity=100   → boost=100    (10× difference)
popularity=1000  → boost=1000   (100× difference for 10× value)
// Problem: Too much variation, popular places dominate

// With log:
popularity=10    → boost=log(11)=1.04
popularity=100   → boost=log(101)=2.0   (2× difference)
popularity=1000  → boost=log(1001)=3.0  (3× difference for 100× value)
// Better: Dampens extreme popularity differences
````

---

### **Popularity Score Table:**

| Popularity | Calculation | Boost | Description |
|-----------|-------------|-------|-------------|
| **0 (missing)** | log₁₀(1 + 1) | **0.30** | Unknown/Unpopular |
| **9** | log₁₀(1 + 9) | **1.0** | Low popularity |
| **20** | log₁₀(1 + 20) | **1.32** | Your document |
| **99** | log₁₀(1 + 99) | **2.0** | Medium |
| **999** | log₁₀(1 + 999) | **3.0** | High |
| **9,999** | log₁₀(1 + 9,999) | **4.0** | Very high |
| **99,999** | log₁₀(1 + 99,999) | **5.0** | Extremely high |
| **10²⁰** | (capped) | **20.0** | Max boost |

---

### **Example: Your HCMC Document**

From `_explanation`:

````json
{
  "value": 1.3222193,
  "description": "field value function: log1p(doc['popularity'].value?:1.0 * factor=1.0)"
}
````

**Calculation:**
````javascript
// Document has popularity=20
popularity = 20

// Apply log1p
popularity_factor = log₁₀(1 + 20)
                  = log₁₀(21)
                  = 1.3222193

// Popularity score
pop_score = 1.0 × 1.3222193 × 1
          = 1.3222193
````

**Popularity provides minimal boost (1.32×) compared to distance (650×)!**

---

## **Phase 5: Final Score Combination**

### **Elasticsearch Bool Query Scoring:**

````json
{
  "value": 1351.3066,
  "description": "sum of:",
  "details": [
    {"value": 699.9845, "description": "phrase match"},
    {"value": 650.0, "description": "geo function score"},
    {"value": 1.3222193, "description": "popularity function score"},
    {"value": 0.0, "description": "filter: source"},
    {"value": 0.0, "description": "filter: layer"}
  ]
}
````

**Formula:**
````javascript
final_score = must_score + sum(should_scores) + sum(filter_scores)
            = text_score + geo_score + popularity_score + 0 + 0
            = 699.98 + 650.0 + 1.32
            = 1351.3
````

---

## **Complete Scoring Examples**

### **Document 1: Đại Học Sư Phạm Kỹ Thuật (HCMC - Close)**

````javascript
// Location: (10.853339, 106.773285)
// Distance from origin: 400m
// Popularity: 20

// Step 1: Text match
text_score = 699.98

// Step 2: Geographic boost
distance = 400m
decay = 1.0 (within offset)
geo_score = 1.0 × 1.0 × 650 = 650.0

// Step 3: Popularity boost
pop_score = log₁₀(21) × 1.0 = 1.32

// Final score
total = 699.98 + 650.0 + 1.32 = 1351.3 ✅ Rank #1
````

---

### **Document 2: Trường Đại học Sư phạm Kỹ thuật (HCMC - Nearby)**

````javascript
// Location: (10.849591, 106.77177)
// Distance from origin: 350m
// Popularity: 15 (assumed)

// Step 1: Text match
text_score = 650.0  // Slightly different text

// Step 2: Geographic boost
distance = 350m
decay = 1.0 (within offset)
geo_score = 1.0 × 1.0 × 650 = 650.0

// Step 3: Popularity boost
pop_score = log₁₀(16) × 1.0 = 1.20

// Final score
total = 650.0 + 650.0 + 1.20 = 1301.2 ✅ Rank #2-4
````

---

### **Document 3: Trường Đại Học Sư Phạm Kỹ Thuật (Đà Nẵng - Far)**

````javascript
// Location: (16.077175, 108.21274)  
// Distance from origin: ~600km
// Popularity: 15 (assumed)

// Step 1: Text match
text_score = 650.0  // Similar text match

// Step 2: Geographic penalty
distance = 600,000m
decay = exp(-599,500 × 0.0004605) = exp(-276.07) ≈ 0.0
geo_score = 1.0 × 0.0 × 650 = 0.0

// Step 3: Popularity boost
pop_score = log₁₀(16) × 1.0 = 1.20

// Final score
total = 650.0 + 0.0 + 1.20 = 651.2 ✅ Rank #5
````

**Problem:** Đà Nẵng only loses 650 points for being 600km away!

---

## **Score Comparison Table**

| Rank | Document | Location | Distance | Text | Geo | Pop | **Total** |
|------|----------|----------|----------|------|-----|-----|-----------|
| 1 | DHSPKT | HCMC | 400m | 700 | 650 | 1.3 | **1351** |
| 2-4 | DHSPKT TPHCM | HCMC | 350m | 650 | 650 | 1.2 | **1301** |
| **5** | **DHSPKT** | **Đà Nẵng** | **600km** | **650** | **0** | **1.2** | **651** ⚠️ |
| 6 | DHSPKT TP.HCM | HCMC | 600m | 608 | 641 | 1.3 | **1250** |

**Issue:** 650-point difference is only 2× when it should be 100×+ for such distance!

---

## **Why Ranking Fails**

### **Problem: Addition vs Multiplication**

````javascript
// Current (Addition):
HCMC:    700 + 650 + 1.3 = 1351  (nearby gets +650 bonus)
Đà Nẵng: 650 + 0 + 1.2 = 651    (far gets 0 penalty)
Ratio: 1351/651 = 2.07× difference

// If using Multiplication:
HCMC:    700 × 1.0 × 1.3 = 910   (nearby multiplied by 1.0)
Đà Nẵng: 650 × 0.0001 × 1.2 = 0.078  (far multiplied by 0.0001)
Ratio: 910/0.078 = 11,666× difference ✅
````

**Addition provides BONUS, not PENALTY!**

---

## **Summary: Query Flow**

````
1. FILTER Phase (No scoring)
   ├─ Source: Keep only [1,2,3,4]
   └─ Layer: Keep only [venue, address, street, locality, county, region]
   Result: 5.5M → 50K candidates
   
2. MUST Phase (Required, scored)
   └─ Text Match: BM25(query="đại học sư pham ky thuat")
      ├─ Analyze text → tokens
      ├─ Calculate IDF (term rarity)
      ├─ Calculate TF (term frequency in doc)
      └─ Score = boost(2.2) × IDF(762.63) × TF(0.417) = 699.98
   
3. SHOULD Phase - Geo (Optional boost, scored)
   └─ Geographic Distance
      ├─ Calculate distance from origin
      ├─ Apply exponential decay
      └─ Score = match_all(1.0) × decay × weight(650) = 0-650
   
4. SHOULD Phase - Pop (Optional boost, scored)
   └─ Popularity
      ├─ Get popularity from doc
      ├─ Apply log10(1 + value)
      └─ Score = match_all(1.0) × log(pop) × weight(1) = 0.3-20
   
5. Combine Scores (Sum)
   └─ Total = Text + Geo + Pop + 0 + 0
      = 699.98 + 650.0 + 1.32
      = 1351.3
````

---

## **Key Parameter Summary**

### **Text Matching:**
- `type: phrase_prefix` - Match phrase, last word can be prefix
- `slop: 4` - Allow 4 words between matched terms
- `boost: 2.2` - Elasticsearch internal phrase bonus
- `k1: 1.2` - BM25 term saturation
- `b: 0.75` - BM25 length normalization

### **Geographic Boost:**
- `weight: 650` - Amplifies distance effect
- `offset: 0.5km` - Full score within 500m
- `scale: 5km` - Half-decay distance
- `decay: 0.1` - At 5.5km, score drops to 10%
- `boost_mode: multiply` - Score = query × decay × weight

### **Popularity Boost:**
- `modifier: log1p` - log₁₀(1 + value)
- `weight: 1` - No amplification
- `max_boost: 20` - Cap at 20×
- `missing: 1` - Default value if field absent

### **Score Combination:**
- Bool query: **ADDITION** (must + should + should)
- Not multiplication!

---

## **To Fix Ranking Issue:**

**Increase geographic weight dramatically:**

````json
{
  "weight": 2000,  // Instead of 650
  "exp": {
    "center_point": {
      "origin": {"lat": 10.85, "lon": 106.77},
      "offset": "0km",    // Start decay immediately
      "scale": "3km",     // Faster decay
      "decay": 0.01       // More aggressive (99% drop at 3km)
    }
  }
}
````

**Expected result:**
- HCMC: 650 + 2000 + 1.3 = **2651**
- Đà Nẵng: 650 + 0 + 1.2 = **651**
- Ratio: 4× difference (better, but still not ideal)

**Best solution:** Restructure to use outer `function_score` with multiplication!








# Detailed Explanation: boost_mode Options in function_score

The `boost_mode` parameter controls **how the function score combines with the query score**. Let's explore all options:

---

## **boost_mode Options**

| Value | Formula | When to Use |
|-------|---------|-------------|
| `multiply` | `score = query_score × function_result` | Default, balanced boost |
| `replace` | `score = function_result` | Ignore text relevance, only use function |
| `sum` | `score = query_score + function_result` | Additive boost |
| `avg` | `score = (query_score + function_result) / 2` | Balanced average |
| `min` | `score = min(query_score, function_result)` | Conservative, take lower |
| `max` | `score = max(query_score, function_result)` | Aggressive, take higher |

---

## **Your Current Configuration**

````json
{
  "function_score": {
    "query": {"match_all": {}},
    "functions": [{
      "weight": 650,
      "exp": {...}
    }],
    "score_mode": "avg",       // ← Combines multiple functions (only 1 here)
    "boost_mode": "multiply"    // ← This one matters!
  }
}
````

**Current calculation:**
````javascript
query_score = match_all = 1.0
function_result = decay × weight = 1.0 × 650 = 650

boost_mode = "multiply"
final_score = query_score × function_result
            = 1.0 × 650
            = 650
````

---

## **1. boost_mode: "multiply" (Current)**

### **Formula:**
````javascript
final_score = query_score × function_result
````

### **Example with your data:**

````javascript
// HCMC Document (400m away)
query_score = match_all = 1.0
decay = 1.0 (within offset)
function_result = 1.0 × 650 = 650

final_score = 1.0 × 650 = 650 ✅

// Đà Nẵng Document (600km away)
query_score = match_all = 1.0
decay = 0.0
function_result = 0.0 × 650 = 0

final_score = 1.0 × 0 = 0 ✅
````

### **Total score in bool query:**
````javascript
total = text(700) + geo(650) + pop(1.3) = 1351.3  // HCM
total = text(650) + geo(0) + pop(1.2) = 651.2     // Đà Nẵng
````

**Behavior:**
- ✅ Function multiplies the query score
- ✅ Works well when query score varies
- ❌ In your case, query is `match_all` (always 1.0), so multiplication doesn't help

---

## **2. boost_mode: "replace"**

### **Formula:**
````javascript
final_score = function_result
// Completely ignores query_score!
````

### **Example with your data:**

````javascript
// HCMC Document (400m away)
query_score = 1.0 // ← IGNORED
function_result = 1.0 × 650 = 650

final_score = 650 ✅

// Đà Nẵng Document (600km away)
query_score = 1.0 // ← IGNORED
function_result = 0.0 × 650 = 0

final_score = 0 ✅
````

### **Total score in bool query:**
````javascript
total = text(700) + geo(650) + pop(1.3) = 1351.3  // HCMC
total = text(650) + geo(0) + pop(1.2) = 651.2     // Đà Nẵng
````

**Wait, same result!** Why?

Because `match_all` always returns 1.0:
- `multiply`: `1.0 × 650 = 650`
- `replace`: just `650`

**They're identical when query_score = 1.0!**

---

### **When "replace" Makes a Difference:**

If your function_score had a **real query** (not match_all):

````json
{
  "function_score": {
    "query": {
      "multi_match": {  // ← Real query!
        "query": "đại học",
        "fields": ["phrase.default"]
      }
    },
    "functions": [{...}],
    "boost_mode": "replace"
  }
}
````

**Example:**

````javascript
// Document A: "Đại học Sư phạm" (good text match, far away)
text_score = 15.5
decay = 0.01
function_result = 0.01 × 650 = 6.5

// With multiply:
final_score = 15.5 × 6.5 = 100.75

// With replace:
final_score = 6.5  // ← Text score ignored!
````

**Use case for "replace":**
- Pure geo-ranking (e.g., "show nearest restaurants")
- Sort by popularity/date only
- Custom scoring formulas where text relevance doesn't matter

---

## **3. boost_mode: "sum"**

### **Formula:**
````javascript
final_score = query_score + function_result
````

### **Example with your data:**

````javascript
// HCMC Document
query_score = 1.0
function_result = 650

final_score = 1.0 + 650 = 651 ✅

// Đà Nẵng Document
query_score = 1.0
function_result = 0

final_score = 1.0 + 0 = 1.0 ✅
````

### **Total score in bool query:**
````javascript
total = text(700) + geo(651) + pop(1.3) = 1352.3  // HCMC
total = text(650) + geo(1.0) + pop(1.2) = 652.2   // Đà Nẵng
````

**Result:** Almost no change! Still only ~2× difference.

**When "sum" is useful:**
- When function adds a constant bonus (e.g., +100 for verified venues)
- When combining multiple small boosts
- Not useful for your distance-based penalty

---

## **4. boost_mode: "avg"**

### **Formula:**
````javascript
final_score = (query_score + function_result) / 2
````

### **Example with your data:**

````javascript
// HCMC Document
query_score = 1.0
function_result = 650

final_score = (1.0 + 650) / 2 = 325.5 ✅

// Đà Nẵng Document
query_score = 1.0
function_result = 0

final_score = (1.0 + 0) / 2 = 0.5 ✅
````

### **Total score in bool query:**
````javascript
total = text(700) + geo(325.5) + pop(1.3) = 1026.8  // HCMC
total = text(650) + geo(0.5) + pop(1.2) = 651.7     // Đà Nẵng
````

**Result:** Ratio = 1.58× (worse than multiply!)

**When "avg" is useful:**
- Balance between query and function scores
- Prevents one from dominating
- Smooths out extreme values

---

## **5. boost_mode: "min"**

### **Formula:**
````javascript
final_score = min(query_score, function_result)
````

### **Example with your data:**

````javascript
// HCMC Document
query_score = 1.0
function_result = 650

final_score = min(1.0, 650) = 1.0 ✅

// Đà Nẵng Document
query_score = 1.0
function_result = 0

final_score = min(1.0, 0) = 0 ✅
````

### **Total score in bool query:**
````javascript
total = text(700) + geo(1.0) + pop(1.3) = 702.3   // HCMC
total = text(650) + geo(0) + pop(1.2) = 651.2     // Đà Nẵng
````

**Result:** Only 1.08× difference! Very bad for geo-ranking.

**When "min" is useful:**
- Quality filters (e.g., "score must be > threshold")
- Conservative scoring
- Prevent over-boosting

---

## **6. boost_mode: "max"**

### **Formula:**
````javascript
final_score = max(query_score, function_result)
````

### **Example with your data:**

````javascript
// HCMC Document
query_score = 1.0
function_result = 650

final_score = max(1.0, 650) = 650 ✅

// Đà Nẵng Document
query_score = 1.0
function_result = 0

final_score = max(1.0, 0) = 1.0 ✅
````

### **Total score in bool query:**
````javascript
total = text(700) + geo(650) + pop(1.3) = 1351.3  // HCMC
total = text(650) + geo(1.0) + pop(1.2) = 652.2   // Đà Nẵng
````

**Result:** 2.07× difference (similar to multiply/replace)

**When "max" is useful:**
- "Best of" scoring
- Fall back to query score if function fails
- Ensure minimum score

---

## **Comparison Table: All boost_mode Values**

| boost_mode | HCMC Score | Đà Nẵng Score | Ratio | Behavior |
|------------|------------|---------------|-------|----------|
| **multiply** | 650 | 0 | ∞ | `1.0 × 650 = 650` |
| **replace** | 650 | 0 | ∞ | Just `650` (same as multiply when query=1) |
| **sum** | 651 | 1.0 | 651× | `1.0 + 650 = 651` |
| **avg** | 325.5 | 0.5 | 651× | `(1.0 + 650) / 2` |
| **min** | 1.0 | 0 | ∞ | `min(1.0, 650) = 1.0` |
| **max** | 650 | 1.0 | 650× | `max(1.0, 650) = 650` |

**After adding to text score (700 HCMC, 650 Đà Nẵng):**

| boost_mode | HCMC Total | Đà Nẵng Total | Ratio | Good for Geo? |
|------------|------------|---------------|-------|---------------|
| **multiply** | 1351.3 | 651.2 | 2.07× | ❌ No |
| **replace** | 1351.3 | 651.2 | 2.07× | ❌ No |
| **sum** | 1352.3 | 652.2 | 2.07× | ❌ No |
| **avg** | 1026.8 | 651.7 | 1.58× | ❌ No |
| **min** | 702.3 | 651.2 | 1.08× | ❌ Worst! |
| **max** | 1351.3 | 652.2 | 2.07× | ❌ No |

**Conclusion:** None of them fix your problem! The issue is the bool query structure (addition), not boost_mode.

---

## **Why boost_mode Doesn't Help You**

### **Root Cause:**

````javascript
// Your current structure:
{
  "bool": {
    "must": [text_query],           // Score: 700
    "should": [
      {
        "function_score": {          // Score: 650 (nearby) or 0 (far)
          "query": {"match_all": {}},
          "boost_mode": "multiply"   // ← Doesn't matter much!
        }
      }
    ]
  }
}

// Bool combines with ADDITION:
total = must_score + should_score
      = 700 + 650 = 1350  (nearby)
      = 700 + 0 = 700     (far)

// Only 1.93× difference!
````

**The problem:**
1. `boost_mode` only affects how function combines with `match_all`
2. But `match_all` is always 1.0, so boost_mode has minimal impact
3. The real issue is bool query uses **addition**, not multiplication
4. 650-point bonus is only ~50% of text score (700)

---

## **Real Solution: Change Structure**

### **Option 1: Move function_score Outside (Best)**

````json
{
  "query": {
    "function_score": {
      "query": {
        "bool": {
          "must": [{"multi_match": {...}}],
          "filter": [...]
        }
      },
      "functions": [
        {
          "exp": {...},
          "weight": 10
        }
      ],
      "score_mode": "multiply",
      "boost_mode": "multiply"  // ← Now this matters!
    }
  }
}
````

**Calculation:**
````javascript
// HCMC
text_score = 700
geo_decay = 1.0
final = 700 × 1.0 × 10 = 7000 ✅

// Đà Nẵng
text_score = 650
geo_decay = 0.0001
final = 650 × 0.0001 × 10 = 0.65 ✅

// Ratio: 10,769× difference! 🎉
````

---

### **Option 2: Increase Weight Dramatically**

Keep current structure, but make geo score >> text score:

````json
{
  "function_score": {
    "query": {"match_all": {}},
    "functions": [{
      "weight": 5000,  // ← Much higher than text score
      "exp": {...}
    }],
    "boost_mode": "multiply"
  }
}
````

**Calculation:**
````javascript
// HCMC
total = text(700) + geo(5000 × 1.0) + pop(1.3)
      = 700 + 5000 + 1.3
      = 5701.3 ✅

// Đà Nẵng
total = text(650) + geo(5000 × 0.0) + pop(1.2)
      = 650 + 0 + 1.2
      = 651.2 ✅

// Ratio: 8.75× difference (better, but still not ideal)
````

---

## **boost_mode with Different Query Types**

### **Example 1: Real Text Query**

````json
{
  "function_score": {
    "query": {
      "match": {
        "name": "coffee"
      }
    },
    "functions": [{
      "exp": {...},
      "weight": 2
    }],
    "boost_mode": "multiply"
  }
}
````

**Scores:**

| Document | Text Score | Decay | boost_mode | Final Score |
|----------|-----------|-------|------------|-------------|
| "Coffee House" (near) | 10.5 | 1.0 | `multiply` | 10.5 × 2.0 = **21** |
| "Coffee Bar" (far) | 8.0 | 0.1 | `multiply` | 8.0 × 0.2 = **1.6** |
| | | | `replace` | **0.2** (ignores 8.0) |
| | | | `sum` | 8.0 + 0.2 = **8.2** |
| | | | `avg` | (8.0 + 0.2)/2 = **4.1** |

**Now boost_mode makes a big difference!**

---

### **Example 2: Sorting by Distance Only**

````json
{
  "function_score": {
    "query": {"match_all": {}},
    "functions": [{
      "exp": {...}
    }],
    "boost_mode": "replace"  // ← Ignore match_all
  }
}
````

**Result:** Pure distance-based ranking

---

## **score_mode vs boost_mode**

Many people confuse these two parameters:

### **score_mode:** Combines **multiple functions**

````json
{
  "function_score": {
    "query": {...},
    "functions": [
      {"exp": {...}},           // Function 1 = 0.8
      {"field_value_factor": {...}}  // Function 2 = 1.5
    ],
    "score_mode": "multiply"  // ← 0.8 × 1.5 = 1.2
  }
}
````

**Options:** `multiply`, `sum`, `avg`, `min`, `max`, `first`

---

### **boost_mode:** Combines **function result with query score**

````json
{
  "function_score": {
    "query": {...},            // Query score = 10
    "functions": [...],        // Combined function = 1.2 (from above)
    "boost_mode": "multiply"   // ← 10 × 1.2 = 12
  }
}
````

**Options:** Same as score_mode + `replace`

---

## **Summary**

### **For Your Use Case:**

| boost_mode | Effect | Useful? |
|------------|--------|---------|
| `multiply` | `1.0 × 650 = 650` | ❌ Same as replace |
| `replace` | Just `650` | ❌ Same as multiply |
| `sum` | `1.0 + 650 = 651` | ❌ Minimal change |
| `avg` | `(1.0 + 650)/2 = 325` | ❌ Reduces boost |
| `min` | `min(1.0, 650) = 1.0` | ❌ Worst option |
| `max` | `max(1.0, 650) = 650` | ❌ Same as multiply |

**None fix the core issue because:**
1. Your query is `match_all` (always 1.0)
2. Bool query uses addition (not multiplication)
3. boost_mode only affects `query × function`, not `must + should`

### **Real Solutions:**

1. ✅ **Move function_score outside bool query** (multiplication)
2. ✅ **Increase weight to 2000-5000** (make geo >> text)
3. ✅ **Make decay more aggressive** (offset=0km, scale=2km, decay=0.01)
4. ❌ Changing boost_mode won't help significantly

### **When boost_mode Matters:**

- ✅ When query has **variable scores** (real text search, not match_all)
- ✅ When you want to **ignore query score** (boost_mode=replace)
- ✅ When balancing **query vs function importance**
- ❌ Not when query is match_all with bool addition structure!

**TL;DR:** In your case, `boost_mode` doesn't matter much because `match_all=1.0`. The real fix is restructuring the query or dramatically increasing weight!








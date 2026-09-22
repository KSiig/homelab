-- Priskurven observations (M1, SII-109).
-- One row per (source, source_sku, observed_at). M1 always inserts (SII-103),
-- so the history (SII-99) for a given (source, source_sku) accumulates by
-- appending new observed_at values rather than overwriting them.
CREATE TABLE IF NOT EXISTS observations (
  source      TEXT NOT NULL,
  source_sku  TEXT NOT NULL,
  observed_at TEXT NOT NULL,   -- ISO 8601 UTC with milliseconds
  price       REAL NOT NULL,
  currency    TEXT NOT NULL,   -- 'DKK'
  name        TEXT,
  brand       TEXT,
  size_value  REAL,
  size_unit   TEXT,
  gtins       TEXT NOT NULL,   -- JSON array, may be []
  raw         TEXT NOT NULL,   -- JSON
  PRIMARY KEY (source, source_sku, observed_at)
);

-- Cheap "latest observation per (source, source_sku)" lookups.
CREATE INDEX IF NOT EXISTS idx_observations_source_sku_observed_at_desc
  ON observations(source, source_sku, observed_at DESC);
-- M2 listings, products, and product_slots (SII-128).
--
-- `listings` is the latest known product card per (source, source_sku).
-- One row per pair. The daily observations insert is unchanged. The
-- writer (SII-130) keeps this row current; the API (SII-129) reads it.
--
-- `products` is the canonical label a person (or, later, a matcher)
-- groups. `id` is an autoincrement integer. Labels are not unique on
-- purpose — two products can share a label while their slots diverge.
--
-- `product_slots` is one row per (product, source). The unique
-- (source, source_sku) index keeps one listing on one product. A
-- missing row means the store has no match for that product yet.
--
-- No foreign key: D1's CHECK enforcement is enough and a foreign key
-- would couple the migration to the writer's every shape change.
--
-- No secondary index on `listings`: the primary key is the only access
-- path the writer and the API need (latest observation by pair, search
-- by source + name). D1 bills one row written per insert.
--
-- Backfill:
--   One row per distinct (source, source_sku) pair. The `observations`
--   table already has 49,050 distinct pairs and 96,552 rows. The
--   backfill copies one row per pair, so it bills 49,050 writes. The
--   free plan caps rows written at 100,000 per UTC day. A full collect
--   adds at most 49,050 more rows. Together they fit; merge on a UTC
--   day that still has headroom.

CREATE TABLE listings (
  source      TEXT NOT NULL,
  source_sku  TEXT NOT NULL,
  currency    TEXT NOT NULL,
  name        TEXT,
  brand       TEXT,
  size_value  REAL,
  size_unit   TEXT,
  gtins       TEXT NOT NULL DEFAULT '[]',
  PRIMARY KEY (source, source_sku)
) WITHOUT ROWID;

CREATE TABLE products (
  id    INTEGER PRIMARY KEY,
  label TEXT NOT NULL
);

CREATE TABLE product_slots (
  product_id  INTEGER NOT NULL,
  source      TEXT NOT NULL,
  source_sku  TEXT NOT NULL,
  matched_by  TEXT NOT NULL CHECK (matched_by IN ('manual', 'ean')),
  PRIMARY KEY (product_id, source),
  UNIQUE (source, source_sku)
) WITHOUT ROWID;

INSERT INTO listings (
  source, source_sku, currency, name, brand, size_value, size_unit, gtins
)
SELECT
  o.source, o.source_sku, o.currency, o.name, o.brand,
  o.size_value, o.size_unit, o.gtins
FROM observations AS o
INNER JOIN (
  SELECT source, source_sku, MAX(observed_at) AS observed_at
  FROM observations
  GROUP BY source, source_sku
) AS latest
  ON o.source = latest.source
 AND o.source_sku = latest.source_sku
 AND o.observed_at = latest.observed_at;

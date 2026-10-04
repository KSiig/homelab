-- Hard-reset the priskurven observations store (SII-118).
--
-- M1.1 ships this migration; merge homelab first, then the priskurven
-- pull request that points the writer at the new table.
--
-- Why DROP TABLE and not DELETE FROM observations:
--   D1 bills rows-written. A full DELETE of the spar/minkobmand/rema/
--   netto/lidl rows left by homelab #29 and priskurven #26 would count
--   toward the 100,000 rows-written daily cap on the free plan. The
--   pre-0002 table observations_v2 is also dropped here. DROP TABLE
--   does not count as rows written.
--
-- Why no `raw` column:
--   observations_v2 already dropped it. The hotfix kept `raw` on the
--   legacy observations table for backward compat. After this reset
--   the table is one v1 schema; nothing in /v1/history ever read
--   `raw` (SII-99), and the writer (SII-93) does not need it.
--
-- Why WITHOUT ROWID and no secondary index:
--   The primary key (source, source_sku, observed_at) becomes the only
--   btree. One product is one billed row written. /v1/history sorts in
--   the Worker (SII-99), so no observed_at DESC index is needed.

DROP TABLE IF EXISTS observations;
DROP TABLE IF EXISTS observations_v2;

CREATE TABLE observations (
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
  PRIMARY KEY (source, source_sku, observed_at)
) WITHOUT ROWID;

-- New collects insert into observations_v2. WITHOUT ROWID makes the
-- primary key the only btree, so D1 bills one row written per product.
-- The old observations table keeps the price history already stored.
-- Its secondary index matched the primary key and is unused by
-- /v1/history, which sorts in the Worker.
--
-- Bilka rows are deleted here. On 2026-10-04 those 39,300 rows held
-- 306 MB of raw JSON and the database file was 499,978,240 bytes, at
-- the free-plan 500 MB cap. A full copy of every row would also exceed
-- the 100,000 rows-written daily allowance. Bilka is recollected into
-- observations_v2. The other sources stay in observations.

DROP INDEX IF EXISTS idx_observations_source_sku_observed_at_desc;

DELETE FROM observations
WHERE rowid IN (
  SELECT rowid FROM observations WHERE source = 'bilkatogo' LIMIT 4000
);
DELETE FROM observations
WHERE rowid IN (
  SELECT rowid FROM observations WHERE source = 'bilkatogo' LIMIT 4000
);
DELETE FROM observations
WHERE rowid IN (
  SELECT rowid FROM observations WHERE source = 'bilkatogo' LIMIT 4000
);
DELETE FROM observations
WHERE rowid IN (
  SELECT rowid FROM observations WHERE source = 'bilkatogo' LIMIT 4000
);
DELETE FROM observations
WHERE rowid IN (
  SELECT rowid FROM observations WHERE source = 'bilkatogo' LIMIT 4000
);
DELETE FROM observations
WHERE rowid IN (
  SELECT rowid FROM observations WHERE source = 'bilkatogo' LIMIT 4000
);
DELETE FROM observations
WHERE rowid IN (
  SELECT rowid FROM observations WHERE source = 'bilkatogo' LIMIT 4000
);
DELETE FROM observations
WHERE rowid IN (
  SELECT rowid FROM observations WHERE source = 'bilkatogo' LIMIT 4000
);
DELETE FROM observations
WHERE rowid IN (
  SELECT rowid FROM observations WHERE source = 'bilkatogo' LIMIT 4000
);
DELETE FROM observations
WHERE rowid IN (
  SELECT rowid FROM observations WHERE source = 'bilkatogo' LIMIT 4000
);
DELETE FROM observations
WHERE rowid IN (
  SELECT rowid FROM observations WHERE source = 'bilkatogo' LIMIT 4000
);
DELETE FROM observations
WHERE rowid IN (
  SELECT rowid FROM observations WHERE source = 'bilkatogo' LIMIT 4000
);

CREATE TABLE IF NOT EXISTS observations_v2 (
  source      TEXT NOT NULL,
  source_sku  TEXT NOT NULL,
  observed_at TEXT NOT NULL,
  price       REAL NOT NULL,
  currency    TEXT NOT NULL,
  name        TEXT,
  brand       TEXT,
  size_value  REAL,
  size_unit   TEXT,
  gtins       TEXT NOT NULL,
  PRIMARY KEY (source, source_sku, observed_at)
) WITHOUT ROWID;

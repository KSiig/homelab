-- M4 backoffice. A row means the approval queue hides this listing.
-- The primary key is the only access path. No foreign key.

CREATE TABLE review_skips (
  source      TEXT NOT NULL,
  source_sku  TEXT NOT NULL,
  skipped_at  TEXT NOT NULL,
  PRIMARY KEY (source, source_sku)
) WITHOUT ROWID;

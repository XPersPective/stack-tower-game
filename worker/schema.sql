-- PB-012 — D1 şeması (SPEC §7.3). Kimlik = sağlayıcı sub; e-posta YOK.
CREATE TABLE IF NOT EXISTS users (
  sub          TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  created_at   INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS scores (
  sub        TEXT NOT NULL,
  board      TEXT NOT NULL CHECK (board IN ('daily','endless')),
  day        INTEGER NOT NULL,
  score      INTEGER NOT NULL CHECK (score >= 0),
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (sub, board, day),
  FOREIGN KEY (sub) REFERENCES users(sub) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_board_score ON scores (board, day, score DESC);

-- Run this once against your CollabBoard database.
-- MySQL allows many NULLs in a UNIQUE column, so boards without a share
-- link are unaffected.

ALTER TABLE boards
  ADD COLUMN share_token VARCHAR(64) NULL,
  ADD UNIQUE KEY uniq_boards_share_token (share_token);

-- Verify:
-- SHOW COLUMNS FROM boards LIKE 'share_token';

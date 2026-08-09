-- Additive migration for the already-running project (schema.sql already
-- has this built in for fresh installs — this is for your existing
-- database). Preserves all existing rows; only adds a constraint.
--
-- Run in the Supabase SQL Editor.

alter table log_entry
  add constraint log_entry_habit_date_unique unique (habit_id, date);

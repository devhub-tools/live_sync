LiveSync.Repo.start_link()
LiveSync.Endpoint.start_link()

LiveSync.Repo.query!("DROP TABLE IF EXISTS ignored;")
LiveSync.Repo.query!("DROP TABLE IF EXISTS examples;")
LiveSync.Repo.query("DROP PUBLICATION live_sync;")

LiveSync.Repo.query!("""
CREATE TABLE examples (
  id bytea PRIMARY KEY,
  name text,
  enabled boolean,
  parent_id bytea REFERENCES examples(id),
  organization_id integer,
  input jsonb,
  embed_one jsonb,
  embed_many jsonb
);
""")

LiveSync.Repo.query!("""
CREATE TABLE ignored (
  id bytea PRIMARY KEY,
  name text,
  example_id bytea REFERENCES examples(id),
  organization_id integer
);
""")

Ecto.Migration.Runner.run(LiveSync.Repo, LiveSync.Repo.config(), 1, LiveSync.Migration, :forward, :up, :up, [])

ExUnit.start(capture_log: true)

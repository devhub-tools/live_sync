LiveSync.Repo.start_link()
LiveSync.Endpoint.start_link()

LiveSync.Repo.query!("DROP TABLE IF EXISTS examples;")
LiveSync.Repo.query!("DROP TABLE IF EXISTS ignored;")

LiveSync.Repo.query!("""
CREATE TABLE ignored (
   id bytea PRIMARY KEY,
   name text
);
""")

LiveSync.Repo.query!("""
CREATE TABLE examples (
   id bytea PRIMARY KEY,
   name text,
   enabled boolean,
   parent_id bytea REFERENCES examples(id),
   ignored_id bytea REFERENCES ignored(id)
);
""")

Ecto.Migration.Runner.run(LiveSync.Repo, LiveSync.Repo.config(), 1, LiveSync.Migration, :forward, :down, :down, [])
Ecto.Migration.Runner.run(LiveSync.Repo, LiveSync.Repo.config(), 1, LiveSync.Migration, :forward, :up, :up, [])

ExUnit.start(capture_log: true)

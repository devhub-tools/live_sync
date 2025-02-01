LiveSync.Repo.start_link()
LiveSync.Endpoint.start_link()

LiveSync.Repo.query!("DROP TABLE IF EXISTS examples;")

LiveSync.Repo.query!("""
CREATE TABLE examples (
   id bytea PRIMARY KEY,
   name text,
   enabled boolean
);
""")

Ecto.Migration.Runner.run(LiveSync.Repo, LiveSync.Repo.config(), 1, LiveSync.Migration, :forward, :down, :down, [])
Ecto.Migration.Runner.run(LiveSync.Repo, LiveSync.Repo.config(), 1, LiveSync.Migration, :forward, :up, :up, [])

ExUnit.start(capture_log: true)

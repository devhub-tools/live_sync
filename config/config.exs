import Config

if config_env() == :test do
  config :live_sync, LiveSync.Repo,
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    database: "sync_test#{System.get_env("MIX_TEST_PARTITION")}",
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: System.schedulers_online() * 2

  config :live_sync, ecto_repos: [LiveSync.Repo]
end

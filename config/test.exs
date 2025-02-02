import Config

config :live_sync, LiveSync.Endpoint,
  live_view: [signing_salt: "Ka2S3KAh"],
  secret_key_base: 64 |> :crypto.strong_rand_bytes() |> Base.encode64(),
  debug_errors: true,
  server: false

config :live_sync, LiveSync.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "sync_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :live_sync, ecto_repos: [LiveSync.Repo]

config :logger, level: :error

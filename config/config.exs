import Config

if config_env() == :test do
  config :live_sync, LiveSync.Endpoint,
    live_view: [signing_salt: "Ka2S3KAh"],
    secret_key_base: "dLwJuHuEGKSvwf0TKaE+5CT/9ksLVQhJdwKU9Z6zpaHbnGvTuJH+nTMZNVR7jhO0",
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
end

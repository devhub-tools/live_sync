defmodule LiveSync.Repo do
  use Ecto.Repo,
    otp_app: :live_sync,
    adapter: Ecto.Adapters.Postgres
end

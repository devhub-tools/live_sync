defmodule LiveSync.Endpoint do
  use Phoenix.Endpoint, otp_app: :live_sync

  plug LiveSync.Router
end

defmodule LiveSync.Router do
  use Phoenix.Router, helpers: false

  import Phoenix.LiveView.Router
  import Plug.Conn

  scope "/" do
    live_session :authenticated, on_mount: LiveSync.Router.SetOrganizationId do
      live "/:id", LiveSync.LivePage
      live "/operations/:id", LiveSync.LivePageOperations
      live "/mixed/:id", LiveSync.LivePageMixed
    end
  end

  defmodule SetOrganizationId do
    @moduledoc false
    def on_mount(:default, _params, _session, socket) do
      socket = Phoenix.Component.assign(socket, :organization_id, 1)
      {:cont, socket}
    end
  end
end

defmodule LiveSync.Router do
  use Phoenix.Router, helpers: false

  import Phoenix.LiveView.Router
  import Plug.Conn

  scope "/" do
    live "/:id", LiveSync.LivePage
    live "/operations/:id", LiveSync.LivePageOperations
    live "/mixed/:id", LiveSync.LivePageMixed
  end
end

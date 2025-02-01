defmodule LiveSync.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, name: LiveSync.Registry, keys: :duplicate},
      # TODO: pass in repo config
      {LiveSync.Replication, [name: LiveSync.Replication] ++ DevHub.Repo.config()},
      {Task, fn -> LiveSync.Replication.wait_for_connection!(LiveSync.Replication) end}
    ]

    opts = [strategy: :one_for_one, name: LiveSync.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

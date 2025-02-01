defmodule LiveSync do
  @moduledoc false
  use Supervisor

  import Phoenix.LiveView

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    repo = Keyword.fetch!(opts, :repo)
    otp_app = Keyword.fetch!(opts, :otp_app)

    children = [
      {Registry, name: LiveSync.Registry, keys: :duplicate},
      {LiveSync.Replication, [name: LiveSync.Replication, otp_app: otp_app] ++ repo.config()},
      {Task, fn -> LiveSync.Replication.wait_for_connection!(LiveSync.Replication) end}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defmacro __using__(opts) do
    quote do
      on_mount({LiveSync, unquote(opts)})

      def sync(key, value, socket), do: assign(socket, key, value)

      @before_compile {LiveSync, :add_sync_fallback}

      defoverridable sync: 3
    end
  end

  defmacro add_sync_fallback(_env) do
    quote do
      def sync(key, value, socket), do: assign(socket, key, value)
    end
  end

  def on_mount(opts, _params, _session, socket) do
    if connected?(socket) do
      # TODO: customizable key to restrict for multitenancy
      LiveSync.Replication.subscribe("live_sync")

      {:cont,
       attach_hook(socket, :sync, :handle_info, fn msg, socket ->
         LiveSync.Socket.handle_info(msg, socket, opts)
       end)}
    else
      {:cont, socket}
    end
  end

  def opts(module) do
    LiveSync.Watch.impl_for(struct(module)).opts()
  end

  def lookup_info(struct) do
    case LiveSync.Watch.impl_for(struct) do
      nil -> nil
      impl -> impl.info(struct)
    end
  end
end

defmodule LiveSync do
  @moduledoc false
  import Phoenix.LiveView

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
      LiveSync.Replication.subscribe("sync")

      {:cont,
       attach_hook(socket, :sync, :handle_info, fn msg, socket ->
         LiveSync.Socket.handle_info(msg, socket, opts)
       end)}
    else
      {:cont, socket}
    end
  end

  def opts(module) do
    LiveSync.Sync.impl_for(struct(module)).opts()
  end

  def lookup_info(struct) do
    case LiveSync.Sync.impl_for(struct) do
      nil -> nil
      impl -> impl.info(struct)
    end
  end
end

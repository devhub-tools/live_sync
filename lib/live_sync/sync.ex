defprotocol LiveSync.Sync do
  def info(data)
end

defimpl LiveSync.Sync, for: Any do
  defmacro __deriving__(module, _struct, opts) do
    quote do
      defimpl LiveSync.Sync, for: unquote(module) do
        def opts, do: unquote(opts)

        def info(data) do
          id = Map.get(data, unquote(opts)[:id])
          {unquote(module), id}
        end
      end
    end
  end

  def info(data) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: data,
      description: "LiveSync.Sync protocol must always be explicitly implemented"
  end
end

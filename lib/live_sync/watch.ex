defprotocol LiveSync.Watch do
  @impl true
  defmacro __deriving__(module, opts) do
    quote do
      defimpl LiveSync.Watch, for: unquote(module) do
        def opts, do: unquote(opts)

        def info(data) do
          id = Map.get(data, unquote(opts)[:id] || :id)
          {unquote(module), id}
        end

        def subscription_key(data) do
          Map.get(data, unquote(opts)[:subscription_key])
        end
      end
    end
  end

  def info(struct)
end

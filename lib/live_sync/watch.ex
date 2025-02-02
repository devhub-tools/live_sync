defprotocol LiveSync.Watch do
  @moduledoc """
  Protocol for defining which Ecto schemas to watch for changes.

  Two options are supported:
  - subscription_key (required): The field on the schema that is used to filter messages that a LiveView session is subscribed to
  - table (optional): The table to watch, defaults to the schema's table name, if using a view you need to specify the table name

  Example:

      @derive {LiveSync.Watch,
              [
                subscription_key: :organization_id,
                table: "table"
              ]}
  """
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
  def subscription_key(struct)
end

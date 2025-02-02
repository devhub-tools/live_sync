defmodule LiveSync do
  @moduledoc ~S"""
  LiveSync is the core of all interactions include a postgres replication process and LiveView hooks to automatically sync data to the client.

  ## Installation

  This project builds on top of PostgreSQL replication and it requires PostgreSQL 14+. You must also enable replication in your PostgreSQL instance:

      ALTER SYSTEM SET wal_level='logical';
      ALTER SYSTEM SET max_wal_senders='64';
      ALTER SYSTEM SET max_replication_slots='64';

  Then **you MUST restart your database**.

  Add `live_sync` to the list of dependencies in `mix.exs`:

            def deps do
              [
                {:live_sync, "~> 0.1.0"}
              ]
            end

  Add a migration to setup replication (requires superuser permissions to subscribe to all tables):

            defmodule MyApp.Repo.Migrations.SetupLiveSync do
              use Ecto.Migration

              def up do
                LiveSync.Migration.up()
                # If you don't have superuser you can pass specific tables
                # LiveSync.Migration.up(["table1", "table2"])
              end

              def down do
                LiveSync.Migration.down()
              end
            end

  Add `LiveSync` to your supervision tree:

  * `repo` (required): The Ecto repo to use for replication.

  * `otp_app` (required): The OTP app to use to lookup schemas deriving the watch protocol.

          defmodule MyApp.Application do
            @moduledoc false

            use Application

            @impl true
            def start(_type, _args) do
              children = [
                ...
                {LiveSync, [repo: MyApp.Repo, otp_app: :my_app]}
              ]

              opts = [strategy: :one_for_one, name: MyApp.Supervisor]
              Supervisor.start_link(children, opts)
            end
          end

  ## Usage

  For any Ecto schemas you want to watch, add the `LiveSync.Watch` derive:

    * `id` (optional): The primary key on the schema, defaults to `:id`.

    * `subscription_key` (required): The field on the schema that is used to filter messages before sending to the client.

    * `table` (optional): The table to watch, defaults to the schema's table name, if using a view you need to specify the table name

          defmodule MyApp.MyObject do
            use Ecto.Schema

            @derive {LiveSync.Watch,
                      [
                        subscription_key: :organization_id,
                        table: "objects"
                      ]}

            schema "visible_objects" do
              field :name, :string
              field :organization_id, :integer
            end

            ...
          end

  Add the `LiveSync` macro to any LiveView module you want to automatically sync data:

    * `subscription_key` (required): This is the key that MUST exist in the assigns of the LiveView and is used for the subscription. This value must match what is in the schema's `@derive` attribute.

    * `watch` (required): A list of keys in assigns that should be watched. You may optionally specify a tuple with options. Schema is required for lists of objects to support inserting.

          use LiveSync,
            subscription_key: :organization_id,
            watch: [
              :single_object,
              list_of_objects: [schema: MyApp.MyObject]
            ]

  ## Handling Sync Events

  An optional callback can also be added to the LiveView module to handle the updated data. This callback will be called for each assign key that is watched and changed. It must return the socket with updated assigns.

      def sync(:list_of_objects, updated, socket) do
        updates =
          updated
          |> Enum.filter(&is_nil(&1.executed_at))
          |> Enum.sort_by(& &1.name)
          |> Repo.preload([...])

        assign(socket, list_of_objects: updates)
      end
  """
  use Supervisor

  import Phoenix.LiveView

  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    repo = Keyword.fetch!(opts, :repo)
    otp_app = Keyword.fetch!(opts, :otp_app)

    children =
      case repo.query!("show wal_level;") do
        %Postgrex.Result{command: :show, columns: ["wal_level"], rows: [["logical"]]} ->
          [
            {Registry, name: LiveSync.Registry, keys: :duplicate},
            {LiveSync.Replication, [name: LiveSync.Replication, otp_app: otp_app] ++ repo.config()},
            {Task, fn -> LiveSync.Replication.wait_for_connection!(LiveSync.Replication) end}
          ]

        _not_setup ->
          Logger.error("""
          Postgres replication not enabled, not starting LiveSync.

          To enable replication, run the following commands and restart your database.

          ALTER SYSTEM SET wal_level='logical';
          ALTER SYSTEM SET max_wal_senders='64';
          ALTER SYSTEM SET max_replication_slots='64';
          """)

          []
      end

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

  @doc false
  defmacro add_sync_fallback(_env) do
    quote do
      def sync(key, value, socket), do: assign(socket, key, value)
    end
  end

  @doc false
  def on_mount(opts, _params, _session, socket) do
    socket =
      socket
      |> attach_hook(:live_sync, :handle_params, fn _params, _uri, socket ->
        if connected?(socket) do
          subscription_key = socket.assigns[opts[:subscription_key]]
          LiveSync.Replication.subscribe("live_sync:#{subscription_key}")
        end

        {:cont, socket}
      end)
      |> attach_hook(:sync, :handle_info, fn msg, socket ->
        LiveSync.Socket.handle_info(msg, socket, opts)
      end)

    {:cont, socket}
  end

  def opts(module) do
    LiveSync.Watch.impl_for(struct(module)).opts()
  end

  @doc """
  Returns the info of how to compare the given struct for updates.

      iex> LiveSync.lookup_info(%MyObject{id: 1, organization_id: 2})
      {MyObject, 1}
  """
  def lookup_info(struct) do
    case LiveSync.Watch.impl_for(struct) do
      nil -> nil
      impl -> impl.info(struct)
    end
  end

  @doc """
  Returns the value for the subscription key for the given struct

      iex> LiveSync.subscription_key(%MyObject{id: 1, organization_id: 2})
      2
  """
  def subscription_key(struct) do
    impl = LiveSync.Watch.impl_for(struct)
    impl.subscription_key(struct)
  end
end

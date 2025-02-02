# LiveSync

![coverbot](https://img.shields.io/endpoint?url=https://private.devhub.tools/coverbot/v1/devhub-tools/live_sync/main/badge.json)
[![Hex.pm](https://img.shields.io/hexpm/v/live_sync.svg)](https://hex.pm/packages/live_sync)
[![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/live_sync)

LiveSync allows automatic updating of LiveView assigns by utilizing postgres replication.

## Installation

Add `live_sync` to the list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [
      {:live_sync, "~> 0.1.0"}
    ]
  end
  ```

Add a migration to setup replication:

  ```elixir
  defmodule MyApp.Repo.Migrations.SetupLiveSync do
    use Ecto.Migration

    def up do
      LiveSync.Migration.up()
    end

    def down do
      LiveSync.Migration.down()
    end
  end
  ```

Add `LiveSync` to your supervision tree:

  * `repo` (required): The Ecto repo to use for replication.

  * `otp_app` (required): The OTP app to use to lookup schemas deriving the watch protocol.

    ```elixir
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
    ```

## Usage

For any Ecto schemas you want to watch, add the `LiveSync.Watch` derive:

  * `id` (optional): The primary key on the schema, defaults to `:id`.

  * `subscription_key` (required): The field on the schema that is used to filter messages before sending to the client.

  * `table` (optional): The table to watch, defaults to the schema's table name, if using a view you need to specify the table name

    ```elixir
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
    ```

Add the `LiveSync` macro to any LiveView module you want to automatically sync data:

  * `subscription_key` (required): This is the key that MUST exist in the assigns of the LiveView and is used for the subscription. This value must match what is in the schema's `@derive` attribute.

  * `watch` (required): A list of keys in assigns that should be watched. You may optionally specify a tuple with options. Schema is required for lists of objects to support inserting.


    ```elixir
    use LiveSync,
      subscription_key: :organization_id,
      watch: [
        :single_object,
        list_of_objects: [schema: MyApp.MyObject]
      ]
    ```

## Handling Sync Events

An optional callback can also be added to the LiveView module to handle the updated data. This callback will be called for each assign key that is watched and changed. It must return the socket with updated assigns.

  ```elixir
  def sync(:list_of_objects, updated, socket) do
    updates =
      updated
      |> Enum.filter(&is_nil(&1.executed_at))
      |> Enum.sort_by(& &1.name)
      |> Repo.preload([...])

    assign(socket, list_of_objects: updates)
  end
  ```

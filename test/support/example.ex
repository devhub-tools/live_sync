defmodule LiveSync.Example do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  @derive {LiveSync.Watch, []}

  schema "examples" do
    field :name, :string
    field :enabled, :boolean, default: true
  end
end

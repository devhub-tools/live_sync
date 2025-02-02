defmodule LiveSync.Ignored do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "ignored" do
    field :name, :string
    field :organization_id, :integer

    belongs_to :example, LiveSync.Example, type: :binary_id, foreign_key: :example_id
  end
end

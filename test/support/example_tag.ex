defmodule LiveSync.ExampleTag do
  @moduledoc false
  use Ecto.Schema

  # a join style schema with a composite primary key and no `id` field
  @primary_key false

  schema "example_tags" do
    field :name, :string, primary_key: true

    belongs_to :example, LiveSync.Example, type: :binary_id, foreign_key: :example_id, primary_key: true
  end
end

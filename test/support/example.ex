defmodule LiveSync.Example do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  @derive {LiveSync.Watch, []}

  schema "examples" do
    field :name, :string
    field :enabled, :boolean, default: true

    belongs_to :ignored, LiveSync.Example, type: :binary_id, foreign_key: :ignored_id
    belongs_to :parent, LiveSync.Example, type: :binary_id, foreign_key: :parent_id
    has_many :children, LiveSync.Example, foreign_key: :parent_id
  end
end

defmodule LiveSync.Example do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  @derive {LiveSync.Watch, [subscription_key: :organization_id]}

  schema "examples" do
    field :name, :string
    field :enabled, :boolean, default: true
    field :organization_id, :integer

    belongs_to :parent, LiveSync.Example, type: :binary_id, foreign_key: :parent_id
    has_many :children, LiveSync.Example, foreign_key: :parent_id
    has_many :ignored, LiveSync.Ignored, foreign_key: :example_id
  end
end

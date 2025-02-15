defmodule LiveSync.Example do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  @derive {LiveSync.Watch, [subscription_key: :organization_id]}

  schema "examples" do
    field :name, :string
    field :enabled, :boolean, default: true
    field :organization_id, :integer

    embeds_one :embed_one, EmbedOne, on_replace: :delete do
      field :name, :string
    end

    embeds_many :embed_many, EmbedMany do
      field :name, :string
    end

    belongs_to :parent, LiveSync.Example, type: :binary_id, foreign_key: :parent_id
    has_many :children, LiveSync.Example, foreign_key: :parent_id
    has_many :ignored, LiveSync.Ignored, foreign_key: :example_id
  end

  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:name, :enabled, :organization_id, :parent_id])
    |> cast_embed(:embed_one, with: &embed_changeset/2)
    |> cast_embed(:embed_many, with: &embed_changeset/2)
  end

  def embed_changeset(embed, params) do
    cast(embed, params, [:name])
  end
end

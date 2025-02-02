defmodule LiveSync.Ignored do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "ignored" do
    field :name, :string
  end
end

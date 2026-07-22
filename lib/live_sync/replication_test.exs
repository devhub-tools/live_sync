defmodule LiveSync.ReplicationTest do
  use LiveSync.DataCase

  alias LiveSync.Example
  alias LiveSync.Example.EmbedMany
  alias LiveSync.Example.EmbedOne
  alias LiveSync.Replication
  alias LiveSync.Repo

  @moduletag cleanup: ["ignored", "examples"]

  setup do
    LiveSync.start_link(repo: Repo, otp_app: :live_sync)
    :ok
  end

  test "broadcasts insertions and updates" do
    Replication.subscribe("live_sync:1")

    {:ok, id} =
      Repo.transaction(fn ->
        example =
          %{
            organization_id: 1,
            name: "replication",
            enabled: false,
            input: %{"key" => "value"},
            embed_one: %{name: "one"},
            embed_many: [%{name: "many"}]
          }
          |> Example.changeset()
          |> Repo.insert!()

        example = Repo.update!(change(example, name: "more replication", enabled: true, embed_one: %{name: "embed"}))
        Repo.delete!(example)
        example.id
      end)

    assert_receive {:live_sync,
                    [
                      delete: %Example{id: delete_id, name: nil}
                    ]}

    assert_receive {:live_sync,
                    [
                      update: %Example{
                        id: update_id,
                        name: "more replication",
                        enabled: true,
                        input: %{"key" => "value"},
                        embed_one: %EmbedOne{name: "embed"},
                        embed_many: [%EmbedMany{name: "many"}]
                      },
                      insert: %Example{
                        id: insert_id,
                        name: "replication",
                        enabled: false,
                        input: %{"key" => "value"},
                        embed_one: %EmbedOne{name: "one"},
                        embed_many: [%EmbedMany{name: "many"}]
                      }
                    ]}

    assert id == insert_id
    assert id == update_id
    assert id == delete_id
  end

  test "decodes array columns whose elements need quoting" do
    Replication.subscribe("live_sync:1")

    # Postgres quotes array elements that contain commas, quotes, braces,
    # backslashes or whitespace, and represents an unquoted NULL for nil.
    tags = [
      "DELETE FROM t RETURNING id, name, tags",
      ~s(has "double" quotes),
      "back\\slash",
      "{braced}",
      "",
      # a quoted "NULL" string must stay a string, distinct from a real NULL (nil)
      "NULL",
      nil,
      "plain"
    ]

    {:ok, id} =
      Repo.transaction(fn ->
        # insert the struct directly so changeset empty-value filtering doesn't
        # drop the empty-string element we want to exercise the decoder against
        example = Repo.insert!(%Example{organization_id: 1, name: "arrays", tags: tags})
        Repo.update!(change(example, name: "updated arrays"))
        example.id
      end)

    assert_receive {:live_sync,
                    [
                      update: %Example{id: ^id, name: "updated arrays", tags: ^tags},
                      insert: %Example{id: ^id, name: "arrays", tags: ^tags}
                    ]}
  end
end

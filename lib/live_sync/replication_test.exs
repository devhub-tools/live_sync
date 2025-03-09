defmodule LiveSync.ReplicationTest do
  use LiveSync.DataCase

  alias LiveSync.Example
  alias LiveSync.Example.EmbedMany
  alias LiveSync.Example.EmbedOne
  alias LiveSync.Replication
  alias LiveSync.Repo

  @moduletag cleanup: ["ignored", "examples"]

  setup do
    LiveSync.start_link(repo: LiveSync.Repo, otp_app: :live_sync)
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
                      delete: %LiveSync.Example{id: delete_id, name: nil}
                    ]}

    assert_receive {:live_sync,
                    [
                      update: %LiveSync.Example{
                        id: update_id,
                        name: "more replication",
                        enabled: true,
                        input: %{"key" => "value"},
                        embed_one: %EmbedOne{name: "embed"},
                        embed_many: [%EmbedMany{name: "many"}]
                      },
                      insert: %LiveSync.Example{
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
end

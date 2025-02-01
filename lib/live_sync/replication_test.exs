defmodule LiveSync.ReplicationTest do
  use LiveSync.DataCase

  alias LiveSync.Example
  alias LiveSync.Replication
  alias LiveSync.Repo

  @moduletag cleanup: ["examples"]

  setup do
    LiveSync.start_link(repo: LiveSync.Repo, otp_app: :live_sync)
    :ok
  end

  test "broadcasts insertions and updates" do
    Replication.subscribe("live_sync")

    {:ok, id} =
      Repo.transaction(fn ->
        example = Repo.insert!(%Example{name: "replication", enabled: false})
        example = Repo.update!(change(example, name: "more replication", enabled: true))
        Repo.delete!(example)
        example.id
      end)

    assert_receive {:live_sync,
                    [
                      delete: %LiveSync.Example{id: delete_id, name: nil},
                      update: %LiveSync.Example{id: update_id, name: "more replication", enabled: true},
                      insert: %LiveSync.Example{id: insert_id, name: "replication", enabled: false}
                    ]}

    assert id == insert_id
    assert id == update_id
    assert id == delete_id
  end
end

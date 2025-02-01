defmodule LiveSync.DataCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      import Ecto
      import Ecto.Changeset

      alias Sync.Repo
    end
  end

  # We cannot use the sandbox because it wraps everything in a single transaction
  # and PG snapshot functionality does not work. So we do it manually.
  setup tags do
    LiveSync.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    if tags[:async] do
      raise "cannot have async tests with replication connection"
    end

    Sandbox.checkout(LiveSync.Repo, sandbox: false)

    if cleanup = tags[:cleanup] do
      on_exit(fn ->
        Ecto.Adapters.SQL.Sandbox.checkout(LiveSync.Repo, sandbox: false)
        LiveSync.Repo.query!("TRUNCATE ONLY #{Enum.join(cleanup, ",")}")
      end)
    end

    :ok
  end
end

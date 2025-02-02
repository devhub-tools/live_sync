defmodule LiveSync.ConnCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      import Ecto.Changeset
      import LiveSync.ConnCase
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest

      @endpoint LiveSync.Endpoint
    end
  end

  setup tags do
    LiveSync.DataCase.setup_sandbox(tags)

    conn =
      Phoenix.ConnTest.init_test_session(Phoenix.ConnTest.build_conn(), %{"test" => self()})

    {:ok, conn: conn}
  end
end

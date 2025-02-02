defmodule LiveSync.Migration do
  @moduledoc false
  use Ecto.Migration

  def up do
    execute("CREATE PUBLICATION live_sync FOR ALL TABLES;")
  end

  def down do
    execute("DROP PUBLICATION live_sync;")
  end
end

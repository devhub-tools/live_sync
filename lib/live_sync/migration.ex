defmodule LiveSync.Migration do
  @moduledoc false
  use Ecto.Migration

  def up do
    execute("ALTER SYSTEM SET wal_level='logical';")
    execute("ALTER SYSTEM SET max_wal_senders='64';")
    execute("ALTER SYSTEM SET max_replication_slots='64';")
    execute("CREATE PUBLICATION live_sync FOR ALL TABLES;")
  end

  def down do
    execute("DROP PUBLICATION live_sync;")
  end
end

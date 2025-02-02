# Most of this code was sourced from https://github.com/josevalim/sync.
defmodule LiveSync.Replication do
  @moduledoc false
  use Postgrex.ReplicationConnection

  require Logger

  def start_link(opts) do
    opts = Keyword.put_new(opts, :auto_reconnect, true)
    Postgrex.ReplicationConnection.start_link(__MODULE__, [otp_app: opts[:otp_app]], opts)
  end

  def subscribe(name) do
    if Process.whereis(LiveSync.Registry) do
      Registry.register(LiveSync.Registry, name, [])
    end
  end

  @doc """
  Wait for connection.

  This is typically used by boot to make sure the replication
  is running to avoid unnecessary syncs. It accepts a maximum
  timeout.

  This function will exit if the server is not running.
  It returns `:ok` or `:timeout` otherwise.
  """
  def wait_for_connection!(name, timeout \\ 5000) do
    ref = :erlang.monitor(:process, name, alias: :reply_demonitor)
    send(name, {:wait_for_connection, ref})

    receive do
      :ok ->
        :ok

      {:DOWN, ^ref, _type, _pid, reason} ->
        exit({reason, {__MODULE__, :wait_for_connection!, [name, timeout]}})
    after
      timeout -> :timeout
    end
  end

  ## Callbacks

  @impl true
  def init(opts) do
    path = Application.app_dir(opts[:otp_app], "ebin")

    schemas =
      LiveSync.Watch
      |> Protocol.extract_impls([path])
      |> Map.new(fn schema ->
        opts = LiveSync.opts(schema)

        fields =
          :fields
          |> schema.__schema__()
          |> Map.new(fn field ->
            {to_string(field), schema.__schema__(:type, field)}
          end)

        {opts[:table] || schema.__schema__(:source), %{module: schema, fields: fields}}
      end)

    state = %{
      schemas: schemas,
      relations: %{},
      # {:disconnected, []} | :connected | [operation]
      replication: {:disconnected, []}
    }

    {:ok, state}
  end

  @impl true
  def handle_disconnect(%{replication: replication} = state) do
    waiting =
      case replication do
        {:disconnected, waiting} -> waiting
        _replication -> []
      end

    {:noreply, %{state | replication: {:disconnected, waiting}}}
  end

  @impl true
  def handle_connect(state) do
    slot = random_slot_name()
    query = "CREATE_REPLICATION_SLOT #{slot} TEMPORARY LOGICAL pgoutput NOEXPORT_SNAPSHOT"
    {:query, query, state}
  end

  @impl true
  def handle_info({:wait_for_connection, ref}, state) do
    case state.replication do
      {:disconnected, waiting} ->
        {:noreply, %{state | replication: {:disconnected, [ref | waiting]}}}

      _replication ->
        send(ref, :ok)
        {:noreply, state}
    end
  end

  def handle_info(:disconnect, _state) do
    {:disconnect, "user requested"}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  @impl true
  def handle_result([result], %{replication: {:disconnected, waiting}} = state) do
    %Postgrex.Result{
      command: :create,
      columns: ["slot_name", "consistent_point", "snapshot_name", "output_plugin"],
      rows: [[slot, _lsn, nil, "pgoutput"]]
    } = result

    for ref <- waiting do
      send(ref, :ok)
    end

    query =
      "START_REPLICATION SLOT #{slot} LOGICAL 0/0 (proto_version '2', publication_names 'live_sync')"

    {:stream, query, [], %{state | replication: :connected}}
  end

  def handle_result(%Postgrex.Error{} = error, _state) do
    raise Exception.message(error)
  end

  @impl true
  # https://www.postgresql.org/docs/14/protocol-replication.html
  def handle_data(<<?w, _wal_start::64, _wal_end::64, _clock::64, rest::binary>>, state) do
    case rest do
      <<?B, _lsn::64, _ts::64, _xid::32>> when state.replication == :connected ->
        handle_begin(state)

      <<?C, _flags::8, _commit_lsn::64, lsn::64, _ts::64>> when is_list(state.replication) ->
        handle_commit(lsn, state)

      <<?I, oid::32, ?N, count::16, tuple_data::binary>> when is_list(state.replication) ->
        handle_tuple_data(:insert, oid, count, tuple_data, state)

      <<?U, oid::32, ?N, count::16, tuple_data::binary>> when is_list(state.replication) ->
        handle_tuple_data(:update, oid, count, tuple_data, state)

      <<?U, oid::32, _action, _rest::binary>> when is_list(state.replication) ->
        %{^oid => {schema, table, _columns}} = state.relations

        Logger.error(
          "A primary key of a row has been changed or its replica identity has been set to full, " <>
            "those operations are not currently supported by sync on #{schema}.#{table}"
        )

        {:noreply, state}

      <<?R, oid::32, rest::binary>> ->
        handle_relation(oid, rest, state)

      <<?D, oid::32, ?K, count::16, tuple_data::binary>> when is_list(state.replication) ->
        handle_tuple_data(:delete, oid, count, tuple_data, state)

      _msg ->
        {:noreply, state}
    end
  end

  def handle_data(<<?k, wal_end::64, _clock::64, reply>>, state) do
    messages =
      case reply do
        1 -> [<<?r, wal_end + 1::64, wal_end + 1::64, wal_end + 1::64, current_time()::64, 0>>]
        0 -> []
      end

    {:noreply, messages, state}
  end

  ## Decoding messages

  defp handle_begin(state) do
    {:noreply, %{state | replication: []}}
  end

  defp handle_relation(oid, rest, state) do
    [schema, rest] = :binary.split(rest, <<0>>)
    schema = if schema == "", do: "pg_catalog", else: schema
    [table, <<_replica_identity::8, count::16, rest::binary>>] = :binary.split(rest, <<0>>)
    columns = parse_columns(count, rest)
    state = put_in(state.relations[oid], {schema, table, columns})
    {:noreply, state}
  end

  defp handle_tuple_data(kind, oid, count, tuple_data, state) do
    {schema, table, columns} = Map.fetch!(state.relations, oid)
    data = parse_tuple_data(count, columns, tuple_data)
    operation = %{schema: schema, table: table, op: kind, data: Map.new(data)}
    {:noreply, update_in(state.replication, &[operation | &1])}
  end

  defp handle_commit(_lsn, state) do
    state.replication
    |> Enum.filter(fn data -> Map.has_key?(state.schemas, data.table) end)
    |> Enum.map(fn %{data: data, table: table, op: op} ->
      %{module: module, fields: fields} = state.schemas[table]

      data =
        data
        |> Map.take(Map.keys(fields))
        |> Map.new(fn {k, v} ->
          field = String.to_existing_atom(k)

          value =
            case {fields[k], v} do
              {_type, nil} ->
                nil

              {:boolean, _v} ->
                v == "t"

              {:binary_id, _v} ->
                <<"\\x", a1, a2, a3, a4, a5, a6, a7, a8, b1, b2, b3, b4, c1, c2, c3, c4, d1, d2, d3, d4, e1, e2, e3, e4,
                  e5, e6, e7, e8, e9, e10, e11, e12>> = v

                <<a1, a2, a3, a4, a5, a6, a7, a8, ?-, b1, b2, b3, b4, ?-, c1, c2, c3, c4, ?-, d1, d2, d3, d4, ?-, e1, e2,
                  e3, e4, e5, e6, e7, e8, e9, e10, e11, e12>>

              {type, _v} ->
                Ecto.Type.cast!(type, v)
            end

          {field, value}
        end)

      struct = Ecto.Schema.Loader.load_struct(module, nil, table)
      {op, Map.merge(struct, data)}
    end)
    |> Enum.group_by(fn {op, struct} -> {LiveSync.subscription_key(struct), op == :delete} end)
    |> Enum.each(fn
      {{subscription_key, false}, data} ->
        Registry.dispatch(LiveSync.Registry, "live_sync:#{subscription_key}", fn subscribed ->
          for {pid, _opts} <- subscribed, do: send(pid, {:live_sync, data})
        end)

      # send deletes to all subscribers as only ids are returned
      {{_subscription_key, true}, data} ->
        LiveSync.Registry
        |> Registry.select([{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}])
        |> Enum.each(fn {_key, pid, _opts} ->
          send(pid, {:live_sync, data})
        end)
    end)

    {:noreply, %{state | replication: :connected}}
  end

  # TODO: if an entry has been soft-deleted, we could emit a special delete
  # instruction instead of sending the whole update.
  defp parse_tuple_data(0, [], <<>>), do: []

  defp parse_tuple_data(count, [{name, _oid, _modifier} | columns], data) do
    case data do
      <<?n, rest::binary>> ->
        [{name, nil} | parse_tuple_data(count - 1, columns, rest)]

      # TODO: We are using text for convenience, we must set binary on the protocol
      <<?t, size::32, value::binary-size(size), rest::binary>> ->
        [{name, value} | parse_tuple_data(count - 1, columns, rest)]

      <<?b, _rest::binary>> ->
        raise "binary values not supported by sync"

      <<?u, rest::binary>> ->
        parse_tuple_data(count - 1, columns, rest)
    end
  end

  defp parse_columns(0, <<>>), do: []

  defp parse_columns(count, <<_flags, rest::binary>>) do
    [name, <<oid::32, modifier::32, rest::binary>>] = :binary.split(rest, <<0>>)
    [{name, oid, modifier} | parse_columns(count - 1, rest)]
  end

  ## Helpers

  @epoch DateTime.to_unix(~U[2000-01-01 00:00:00Z], :microsecond)
  defp current_time, do: System.os_time(:microsecond) - @epoch

  defp random_slot_name do
    "live_sync_" <> Base.encode32(:crypto.strong_rand_bytes(5), case: :lower)
  end
end

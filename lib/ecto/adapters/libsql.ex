defmodule Ecto.Adapters.LibSQL do
  @moduledoc """
  Adapter module for libSQL.

  It uses `ExLibSQL` for communicating to the database.

  ## Options

  The adapter supports a superset of the options provided by the
  underlying `ExLibSQL` driver.

  ### Provided options

    * `:mode` - Required. The connection mode (:memory, :local, :local_replica, :remote, :remote_replica)
    * `:path` - Required for :local, :local_replica, and :remote_replica modes
    * `:url` - Required for :remote and :remote_replica modes
    * `:token` - Required for :remote and :remote_replica modes
    * `:flags` - Optional for :memory, :local and :local_replica [:read_only | :read_write | :create]
    * `:remote_replica_opts` - Optional for :remote_replica mode. Additional options for the remote replica connection
      * `:read_your_writes` - Optional [default: true]. Whether to read your own writes
      * `:sync_interval` - Optional. Enables syncing the replica with the primary at the specified interval in milliseconds
    * `:transaction_mode` - Optional [default: :deferred]. The transaction mode (:deferred, :immediate, :exclusive)
    * `:journal_mode` - Optional [default: :wal]. The journal mode (:wal, :delete, :truncate, :memory)
    * `:temp_store` - Optional [default: :memory]. The temp store mode (:default, :file, :memory)
    * `:synchronous` - Optional [default: :normal]. The synchronous mode (:off, :normal, :full, :extra)
    * `:foreign_keys` - Optional [default: :on]. Whether to enable foreign keys (:on, :off)
    * `:cache_size` - Optional [default: -2000]. The cache size in kilobytes
    * `:cache_spill` - Optional [default: :on]. The cache spill mode (:on, :off)
    * `:auto_vacuum` - Optional [default: :none]. The auto vacuum mode (:none, :full, :incremental)
    * `:locking_mode` - Optional [default: :normal]. The locking mode (:normal, :exclusive)
    * `:secure_delete` - Optional [default: :off]. The secure delete mode (:on, :off)
    * `:wal_auto_check_point` - Optional [default: 1000]. The WAL auto check point mode
    * `:case_sensitive_like` - Optional [default: :off]. Whether to use case sensitive LIKE (:on, :off)
    * `:busy_timeout` - Optional [default: 2000]. The busy timeout in milliseconds
  """

  use Ecto.Adapters.SQL,
    driver: :ex_libsql

  @behaviour Ecto.Adapter.Storage
  @behaviour Ecto.Adapter.Structure

  alias Ecto.Adapters.LibSQL.Codec

  require Logger

  @impl Ecto.Adapter.Storage
  def storage_down(options) do
    db_path = Keyword.fetch!(options, :path)

    case File.rm(db_path) do
      :ok ->
        File.rm(db_path <> "-shm")
        File.rm(db_path <> "-wal")
        :ok

      _otherwise ->
        {:error, :already_down}
    end
  end

  @impl Ecto.Adapter.Storage
  def storage_status(options) do
    db_path = Keyword.fetch!(options, :path)

    if File.exists?(db_path) do
      :up
    else
      :down
    end
  end

  @impl Ecto.Adapter.Storage
  def storage_up(options) do
    mode = Keyword.get(options, :mode)
    path = Keyword.get(options, :path)
    pool_size = Keyword.get(options, :pool_size)

    cond do
      is_nil(path) ->
        raise ArgumentError,
              """
              No libSQL database path specified. Please check the configuration for your Repo.
              Your config/*.exs file should have something like this in it:

                config :my_app, MyApp.Repo,
                  adapter: Ecto.Adapters.LibSQL,
                  mode: :local,
                  path: "/path/to/database"
              """

      File.exists?(path) ->
        {:error, :already_up}

      mode == :memory && pool_size != 1 ->
        raise ArgumentError, """
        In memory databases must have a pool_size of 1
        """

      true ->
        {:ok, state} = ExLibSQL.Connection.connect(options)
        :ok = ExLibSQL.Connection.disconnect(:normal, state)
    end
  end

  @impl Ecto.Adapter.Migration
  def supports_ddl_transaction?, do: true

  @impl Ecto.Adapter.Migration
  def lock_for_migrations(_meta, _options, fun) do
    fun.()
  end

  @impl Ecto.Adapter.Structure
  def structure_dump(default, config) do
    path = config[:dump_path] || Path.join(default, "structure.sql")

    with {:ok, contents} <- dump_schema(config),
         {:ok, versions} <- dump_versions(config) do
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, contents <> versions)
      {:ok, path}
    else
      err -> err
    end
  end

  @impl Ecto.Adapter.Structure
  def structure_load(default, config) do
    path = config[:dump_path] || Path.join(default, "structure.sql")

    case run_with_cmd("sqlite3", [config[:database], ".read #{path}"]) do
      {_output, 0} -> {:ok, path}
      {output, _} -> {:error, output}
    end
  end

  @impl Ecto.Adapter.Structure
  def dump_cmd(args, opts \\ [], config) when is_list(config) and is_list(args) do
    run_with_cmd("sqlite3", ["-init", "/dev/null", config[:path] | args], opts)
  end

  @impl Ecto.Adapter.Schema
  def autogenerate(:id), do: nil
  def autogenerate(:embed_id), do: Ecto.UUID.generate()

  def autogenerate(:binary_id) do
    case Application.get_env(:ecto_libsql, :binary_id_type, :string) do
      :string -> Ecto.UUID.generate()
      :binary -> Ecto.UUID.bingenerate()
    end
  end

  ##
  ## Loaders
  ##

  @default_datetime_type :iso8601

  @impl Ecto.Adapter
  def loaders(:binary, type) do
    [&Codec.binary_decode/1, type]
  end

  @impl Ecto.Adapter
  def loaders(:boolean, type) do
    [&Codec.bool_decode/1, type]
  end

  @impl Ecto.Adapter
  def loaders(:naive_datetime_usec, type) do
    [&Codec.naive_datetime_decode/1, type]
  end

  @impl Ecto.Adapter
  def loaders(:time, type) do
    [&Codec.time_decode/1, type]
  end

  @impl Ecto.Adapter
  def loaders(:utc_datetime_usec, type) do
    [&Codec.utc_datetime_decode/1, type]
  end

  @impl Ecto.Adapter
  def loaders(:utc_datetime, type) do
    [&Codec.utc_datetime_decode/1, type]
  end

  @impl Ecto.Adapter
  def loaders(:naive_datetime, type) do
    [&Codec.naive_datetime_decode/1, type]
  end

  @impl Ecto.Adapter
  def loaders(:date, type) do
    [&Codec.date_decode/1, type]
  end

  @impl Ecto.Adapter
  def loaders({:map, _}, type) do
    [&Codec.json_decode/1, &Ecto.Type.embedded_load(type, &1, :json)]
  end

  @impl Ecto.Adapter
  def loaders({:array, _}, type) do
    [&Codec.json_decode/1, type]
  end

  @impl Ecto.Adapter
  def loaders(:map, type) do
    [&Codec.json_decode/1, type]
  end

  @impl Ecto.Adapter
  def loaders(:float, type) do
    [&Codec.float_decode/1, type]
  end

  @impl Ecto.Adapter
  def loaders(:decimal, type) do
    [&Codec.decimal_decode/1, type]
  end

  @impl Ecto.Adapter
  def loaders(:binary_id, type) do
    case Application.get_env(:ecto_libsql, :binary_id_type, :string) do
      :string -> [type]
      :binary -> [&Codec.binary_decode/1, Ecto.UUID, type]
    end
  end

  @impl Ecto.Adapter
  def loaders(:uuid, type) do
    case Application.get_env(:ecto_libsql, :uuid_type, :string) do
      :string -> []
      :binary -> [&Codec.binary_decode/1, type]
    end
  end

  @impl Ecto.Adapter
  def loaders(_, type) do
    [type]
  end

  ##
  ## Dumpers
  ##

  @impl Ecto.Adapter
  def dumpers(:binary, type) do
    [type, &Codec.blob_encode/1]
  end

  @impl Ecto.Adapter
  def dumpers(:boolean, type) do
    [type, &Codec.bool_encode/1]
  end

  @impl Ecto.Adapter
  def dumpers(:decimal, type) do
    [type, &Codec.decimal_encode/1]
  end

  @impl Ecto.Adapter
  def dumpers(:binary_id, type) do
    case Application.get_env(:ecto_libsql, :binary_id_type, :string) do
      :string -> [type]
      :binary -> [type, Ecto.UUID]
    end
  end

  @impl Ecto.Adapter
  def dumpers(:uuid, type) do
    case Application.get_env(:ecto_libsql, :uuid_type, :string) do
      :string -> []
      :binary -> [type]
    end
  end

  @impl Ecto.Adapter
  def dumpers(:time, type) do
    [type, &Codec.time_encode/1]
  end

  @impl Ecto.Adapter
  def dumpers(:utc_datetime, type) do
    dt_type = Application.get_env(:ecto_libsql, :datetime_type, @default_datetime_type)
    [type, &Codec.utc_datetime_encode(&1, dt_type)]
  end

  @impl Ecto.Adapter
  def dumpers(:utc_datetime_usec, type) do
    dt_type = Application.get_env(:ecto_libsql, :datetime_type, @default_datetime_type)
    [type, &Codec.utc_datetime_encode(&1, dt_type)]
  end

  @impl Ecto.Adapter
  def dumpers(:naive_datetime, type) do
    dt_type = Application.get_env(:ecto_libsql, :datetime_type, @default_datetime_type)
    [type, &Codec.naive_datetime_encode(&1, dt_type)]
  end

  @impl Ecto.Adapter
  def dumpers(:naive_datetime_usec, type) do
    dt_type = Application.get_env(:ecto_libsql, :datetime_type, @default_datetime_type)
    [type, &Codec.naive_datetime_encode(&1, dt_type)]
  end

  @impl Ecto.Adapter
  def dumpers({:array, _}, type) do
    [type, &Codec.json_encode/1]
  end

  @impl Ecto.Adapter
  def dumpers({:map, _}, type) do
    [&Ecto.Type.embedded_dump(type, &1, :json), &Codec.json_encode/1]
  end

  @impl Ecto.Adapter
  def dumpers(:map, type) do
    [type, &Codec.json_encode/1]
  end

  @impl Ecto.Adapter
  def dumpers({:supertype, :datetime}, type) do
    dt_type = Application.get_env(:ecto_libsql, :datetime_type, @default_datetime_type)
    [type, &Codec.utc_datetime_encode(&1, dt_type)]
  end

  @impl Ecto.Adapter
  def dumpers(_primitive, type) do
    [type]
  end

  ##
  ## HELPERS
  ##

  defp dump_versions(config) do
    table = config[:migration_source] || "schema_migrations"

    # `.dump` command also returns CREATE TABLE which will clash with CREATE we already run in dump_schema
    # So we set mode to insert which makes every SELECT statement to issue the result
    # as the INSERT statements instead of pure text data.
    case run_with_cmd("sqlite3", [
           config[:path],
           ".mode insert #{table}",
           "SELECT * FROM #{table}"
         ]) do
      {output, 0} -> {:ok, output}
      {output, _} -> {:error, output}
    end
  end

  defp dump_schema(config) do
    case run_with_cmd("sqlite3", [config[:path], ".schema"]) do
      {output, 0} -> {:ok, output}
      {output, _} -> {:error, output}
    end
  end

  defp run_with_cmd(cmd, args, cmd_opts \\ []) do
    unless System.find_executable(cmd) do
      raise "could not find executable `#{cmd}` in path, " <>
              "please guarantee it is available before running ecto commands"
    end

    cmd_opts = Keyword.put_new(cmd_opts, :stderr_to_stdout, true)

    System.cmd(cmd, args, cmd_opts)
  end
end

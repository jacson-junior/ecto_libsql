defmodule Ecto.Adapters.LibSQLConnTest do
  use ExUnit.Case

  alias Ecto.Adapters.LibSQL

  @uuid_regex ~r/^[[:xdigit:]]{8}\b-[[:xdigit:]]{4}\b-[[:xdigit:]]{4}\b-[[:xdigit:]]{4}\b-[[:xdigit:]]{12}$/

  setup do
    original_binary_id_type =
      Application.get_env(:ecto_libsql, :binary_id_type, :string)

    on_exit(fn ->
      Application.put_env(:ecto_libsql, :binary_id_type, original_binary_id_type)
    end)
  end

  describe ".storage_up/1" do
    test "create database" do
      opts = [database: Temp.path!()]

      assert LibSQL.storage_up(opts) == :ok
      assert File.exists?(opts[:path])

      File.rm(opts[:path])
    end

    test "does not fail on second call" do
      opts = [database: Temp.path!()]

      assert LibSQL.storage_up(opts) == :ok
      assert File.exists?(opts[:path])
      assert LibSQL.storage_up(opts) == {:error, :already_up}

      File.rm(opts[:path])
    end

    test "fails with helpful error message if no database specified" do
      assert_raise(
        ArgumentError,
        """
        No SQLite database path specified. Please check the configuration for your Repo.
        Your config/*.exs file should have something like this in it:

          config :my_app, MyApp.Repo,
            adapter: Ecto.Adapters.LibSQL,
            database: "/path/to/database"
        """,
        fn -> LibSQL.storage_up(mumble: "no database here") == :ok end
      )
    end

    test "can create an in memory database" do
      assert LibSQL.storage_up(database: ":memory:", pool_size: 1) == :ok
    end

    test "fails if in memory database does not have a pool size of 1" do
      assert_raise(
        ArgumentError,
        """
        In memory databases must have a pool_size of 1
        """,
        fn -> LibSQL.storage_up(database: ":memory:", pool_size: 2) end
      )
    end
  end

  describe ".storage_down/2" do
    test "storage down (twice)" do
      opts = [database: Temp.path!()]

      assert LibSQL.storage_up(opts) == :ok
      assert LibSQL.storage_down(opts) == :ok
      refute File.exists?(opts[:path])
      assert LibSQL.storage_down(opts) == {:error, :already_down}

      File.rm(opts[:path])
    end
  end

  describe ".autogenerate/1" do
    test ":id must be generated from storage" do
      assert LibSQL.autogenerate(:id) == nil
    end

    test ":embed_id is a UUID in string form" do
      assert string_uuid?(LibSQL.autogenerate(:embed_id))
    end

    test ":binary_id with type :string is a UUID in string form" do
      Application.put_env(:ecto_libsql, :binary_id_type, :string)
      assert string_uuid?(LibSQL.autogenerate(:binary_id))
    end

    test ":binary_id with type :binary is a UUID in binary form" do
      Application.put_env(:ecto_libsql, :binary_id_type, :binary)
      assert binary_uuid?(LibSQL.autogenerate(:binary_id))
    end
  end

  describe "dump_cmd/3" do
    test "runs command" do
      opts = [database: Temp.path!()]

      assert LibSQL.storage_up(opts) == :ok

      assert {_out, 0} =
               LibSQL.dump_cmd(
                 ["CREATE TABLE test (id INTEGER PRIMARY KEY)"],
                 [],
                 opts
               )

      assert {"CREATE TABLE test (id INTEGER PRIMARY KEY);\n", 0} =
               LibSQL.dump_cmd([".schema"], [], opts)
    end
  end

  defp string_uuid?(uuid), do: Regex.match?(@uuid_regex, uuid)
  defp binary_uuid?(uuid), do: bit_size(uuid) == 128
end

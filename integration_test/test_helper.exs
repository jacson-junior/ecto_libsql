Logger.configure(level: :info)

Application.put_env(:ecto, :primary_key_type, :id)
Application.put_env(:ecto, :async_integration_tests, false)

ecto = Mix.Project.deps_paths()[:ecto]
ecto_sql = Mix.Project.deps_paths()[:ecto_sql]

Code.require_file("#{ecto_sql}/integration_test/support/repo.exs", __DIR__)

alias Ecto.Integration.TestRepo

Application.put_env(:ecto_libsql, TestRepo,
  adapter: Ecto.Adapters.LibSQL,
  mode: :local,
  path: "/tmp/ex_libsql_integration_test.db",
  pool: Ecto.Adapters.SQL.Sandbox,
  show_sensitive_data_on_connection_error: true
)

# Pool repo for non-async tests
alias Ecto.Integration.PoolRepo

Application.put_env(:ecto_libsql, PoolRepo,
  adapter: Ecto.Adapters.LibSQL,
  mode: :local,
  path: "/tmp/ex_libsql_integration_pool_test.db",
  show_sensitive_data_on_connection_error: true
)

# needed since some of the integration tests rely on fetching env from :ecto_sql
Application.put_env(:ecto_sql, TestRepo, Application.get_env(:ecto_libsql, TestRepo))
Application.put_env(:ecto_sql, PoolRepo, Application.get_env(:ecto_libsql, PoolRepo))

defmodule Ecto.Integration.PoolRepo do
  use Ecto.Integration.Repo, otp_app: :ecto_libsql, adapter: Ecto.Adapters.LibSQL
end

Code.require_file "#{ecto}/integration_test/support/schemas.exs", __DIR__
Code.require_file "#{ecto_sql}/integration_test/support/migration.exs", __DIR__

defmodule Ecto.Integration.Case do
  use ExUnit.CaseTemplate

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(TestRepo)
  end
end

{:ok, _} = Ecto.Adapters.LibSQL.ensure_all_started(TestRepo.config(), :temporary)

# Load up the repository, start it, and run migrations
_ = Ecto.Adapters.LibSQL.storage_down(TestRepo.config())
:ok = Ecto.Adapters.LibSQL.storage_up(TestRepo.config())

_ = Ecto.Adapters.LibSQL.storage_down(PoolRepo.config())
:ok = Ecto.Adapters.LibSQL.storage_up(PoolRepo.config())

{:ok, _} = TestRepo.start_link()
{:ok, _pid} = PoolRepo.start_link()

excludes = [
  :delete_with_join,
  :right_join,

  # libSQL does not have an array type
  :array_type,
  :transaction_isolation,
  :insert_cell_wise_defaults,
  :insert_select,

  # libSQL does not support microsecond precision, only millisecond
  :microsecond_precision,

  # libSQL supports FKs, but does not return sufficient data
  # for ecto to support matching on a given constraint violation name
  # which is what most of the tests validate
  :foreign_key_constraint,

  # libSQL with DSQLITE_LIKE_DOESNT_MATCH_BLOBS=1
  # does not support using LIKE on BLOB types
  :like_match_blob,

  # libSQL will return a string for schemaless map types as
  # Ecto does not have enough information to call the associated loader
  # that converts the string JSON representation into a map
  :map_type_schemaless,

  # right now in lock_for_migrations() we do effectively nothing, this is because
  # libSQL is single-writer so there isn't really a need for us to do anything.
  # ecto assumes all implementing adapters need >=2 connections for migrations
  # which is not true for libSQL
  :lock_for_migrations,

  # Migration we don't support
  :prefix,
  :add_column_if_not_exists,
  :remove_column_if_exists,
  :alter_primary_key,
  :alter_foreign_key,
  :assigns_id_type,
  :modify_column,
  :restrict,

  # libSQL does not support the concat function
  :concat,

  # libSQL does not support placeholders
  :placeholders,

  # libSQL stores booleans as integers, causing Ecto's json_extract_path tests to fail
  :json_extract_path,

  # libSQL doesn't support specifying columns for ON DELETE SET NULL
  :on_delete_nilify_column_list,

  # not sure how to support this yet
  :bitstring_type,

  # libSQL does not have a duration type... yet
  :duration_type,

  # We don't support selected_as
  :selected_as_with_group_by,
  :selected_as_with_order_by,
  :selected_as_with_order_by_expression,
  :selected_as_with_having,

  # Distinct with options not supported
  :distinct_count,

  # libSQL does not support anything except a single column in DISTINCT
  :multicolumn_distinct,

  # Values list
  :values_list
]

ExUnit.configure(exclude: excludes)

# migrate the pool repo
case Ecto.Migrator.migrated_versions(PoolRepo) do
  [] ->
    :ok = Ecto.Migrator.up(PoolRepo, 0, Ecto.Integration.Migration, log: false)

  _ ->
    :ok = Ecto.Migrator.down(PoolRepo, 0, Ecto.Integration.Migration, log: false)
    :ok = Ecto.Migrator.up(PoolRepo, 0, Ecto.Integration.Migration, log: false)
end

:ok = Ecto.Migrator.up(TestRepo, 0, Ecto.Integration.Migration, log: false)
Ecto.Adapters.SQL.Sandbox.mode(TestRepo, :manual)
Process.flag(:trap_exit, true)

ExUnit.start()

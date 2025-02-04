defmodule Ecto.Adapters.LibSQL.Connection.ToConstraintsTest do
  use ExUnit.Case, async: true

  alias Ecto.Adapters.LibSQL.Connection

  test "unique index" do
    # created with:
    # CREATE UNIQUE INDEX users_email_name_index ON users (email);

    error = %ExLibSQL.Error{message: "UNIQUE constraint failed: users.email"}
    assert Connection.to_constraints(error, []) == [unique: "users_email_index"]
  end

  test "multi-column unique index" do
    # created with:
    # CREATE UNIQUE INDEX users_email_name_index ON users (email, name);

    error = %ExLibSQL.Error{
      message: "UNIQUE constraint failed: users.email, users.name"
    }

    assert Connection.to_constraints(error, []) == [unique: "users_email_name_index"]
  end

  test "complex unique index" do
    # created with:
    # CREATE UNIQUE INDEX users_email_year_index ON users (email, strftime('%Y', inserted_at));

    error = %ExLibSQL.Error{
      message: "UNIQUE constraint failed: index 'users_email_year_index'"
    }

    assert Connection.to_constraints(error, []) == [unique: "users_email_year_index"]
  end
end

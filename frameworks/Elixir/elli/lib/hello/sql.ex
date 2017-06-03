defmodule Hello.SQL do
  @moduledoc false

  @opts [pool: DBConnection.Sojourn, protector: false]

  def child_spec() do
    cache = Supervisor.Spec.worker(Hello.Cache, [])
    force_opts = [name: __MODULE__] ++ @opts
    opts = force_opts ++ Application.get_env(:hello, :sql)
    pg = Postgrex.child_spec(opts)

    args = [[cache, pg], [strategy: :rest_for_one]]
    Supervisor.Spec.supervisor(Supervisor, args)
  end

  def query(conn \\ __MODULE__, name, query, params) do
    case Hello.Cache.fetch(name) do
      {:ok, query} ->
        execute(conn, name, query, params)
      :error ->
        prepare_execute(conn, name, query, params)
    end
  end

  def run(conn \\ __MODULE__, fun) do
    DBConnection.run(conn, fun, @opts)
  end

  def transaction(conn \\ __MODULE__, fun) do
    DBConnection.transaction(conn, fun, @opts)
  end

  # Helpers

 defp prepare_execute(conn, name, statement, params) do
    query = %Postgrex.Query{name: name, statement: statement}
    opts = [function: :prepare_execute] ++ @opts
    case DBConnection.prepare_execute(conn, query, params, opts) do
      {:ok, query, %Postgrex.Result{rows: rows}} ->
        _ = Hello.Cache.insert_new(name, query)
        rows
      {:error, err} ->
        raise err
    end
  end

  defp execute(conn, name, query, params) do
    case DBConnection.execute(conn, query, params, @opts) do
      {:ok, %Postgrex.Result{rows: rows}} ->
        rows
      {:error, %ArgumentError{} = err} ->
        Hello.Cache.delete(name, query)
        raise err
      {:error, %Postgrex.Error{postgres: %{code: :feature_not_supported}}} = err ->
        Hello.Cache.delete(name, query)
        raise err
      {:error, err} ->
        raise err
    end
  end
end

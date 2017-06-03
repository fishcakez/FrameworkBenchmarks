defmodule Hello.API do
  @moduledoc false

  @behaviour :elli_handler

  require EEx

  def child_spec() do
    args = [mods: [{:elli_date, []}, {__MODULE__, []}]]
    opts = [callback: :elli_middleware, callback_args: args] ++ Application.get_env(:hello, :api)
    Supervisor.Spec.worker(:elli, [opts])
  end

  @json_headers [{<<"content-type">>, <<"application/json">>}]
  @html_headers [{<<"content-type">>, <<"text/html">>}]
  @plain_headers [{<<"content-type">>, <<"text/plain">>}]

  def handle(req, _) do
    case :elli_request.path(req) do
      ["json"] ->
        json(req)
      ["db"] ->
        db(req)
      ["queries"] ->
        queries(req)
      ["fortune"] ->
        fortune(req)
      ["update"] ->
        update(req)
      ["plaintext"] ->
        plaintext(req)
      [] ->
        index(req)
      _ ->
        {404, @plain_headers, "Not Found"}
    end
  end

  def handle_event(_, _, _), do: :ok

  defp json(_) do
    {200, @json_headers, :jiffy.encode(%{"message" => "Hello, world!"})}
  end

  @world_by_id "SELECT id, randomnumber FROM world WHERE id = $1"

  defp db(_) do
    id = rand_id()
    try do
      Hello.SQL.query("world_by_id", @world_by_id, [id])
    rescue
      DBConnection.ConnectionError ->
        {503, @plain_headers, "Service Unavailable"}
    else
      [row] ->
        body =
          row
          |> world()
          |> :jiffy.encode()
          {200, @json_headers, body}
    end

  rescue
    err ->
      IO.puts Exception.format(:error, err)
  end

  defp queries(req) do
    n = query_count(req)
    try do
      Hello.SQL.run(fn(conn) ->
        for _ <- 1..n do
          id = rand_id()
          [row] = Hello.SQL.query(conn, "world_by_id", @world_by_id, [id])
          world(row)
        end
      end)
    rescue
      DBConnection.ConnectionError ->
        {503, @plain_headers, "Service Unavailable"}
    else
      worlds ->
        {200, @json_headers, :jiffy.encode(worlds)}
    end
  end

  @fortunes "SELECT id, message FROM fortune"

  defp fortune(_) do
    try do
      Hello.SQL.query("fortunes", @fortunes, [])
    rescue
      DBConnection.ConnectionError ->
        {503, @plain_headers, "Service Unavailable"}
    else
      fortunes ->
        extra = [0, "Additional fortune added at request time."]
        body =
          [extra | fortunes]
          |> Enum.sort_by(fn([_, message]) -> message end)
          |> fortune_html()
        {200, @html_headers, body}
    end
  end

  EEx.function_from_file :defp, :fortune_html, "priv/fortune.eex", [:fortunes]

  @world_update "UPDATE world SET randomnumber = $2 WHERE id = $1"

  defp update(req) do
    n = query_count(req)
    params_list =
      1..n
      |> Enum.reduce([], fn(_, acc) ->
          [[rand_id(), :rand.uniform(10_000)] | acc]
      end)
      |> Enum.sort()
    try do
      Hello.SQL.transaction(fn(conn) ->
        for params <- params_list do
          Hello.SQL.query(conn, "world_update", @world_update, params)
          world(params)
        end
      end)
    rescue
      DBConnection.ConnectionError ->
        {503, @plain_headers, "Service Unavailable"}
    else
      {:ok, worlds} ->
        {200, @json_headers, :jiffy.encode(worlds)}
    end
  end

  defp plaintext(_) do
    {200, @plain_headers, "Hello, World!"}
  end

  defp index(_) do
    {200, @json_headers, :jiffy.encode(%{"TE Benchmarks\n" => "Started"})}
  end

  defp world([id, randomnumber]) do
    %{"id" => id, "randomnumber" => randomnumber}
  end

  defp query_count(req) do
    req
    |> :elli_request.get_args_decoded()
    |> List.keyfind("queries", 0, {"queries", "1"})
    |> elem(1)
    |> String.to_integer()
  end

  defp rand_id() do
    :rand.uniform(10_000)
  end
end

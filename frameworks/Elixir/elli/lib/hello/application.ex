defmodule Hello.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [Hello.SQL.child_spec(), Hello.API.child_spec()]
    opts = [strategy: :one_for_one, name: Hello.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

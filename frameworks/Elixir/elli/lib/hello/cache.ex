defmodule Hello.Cache do
  @moduledoc false

  use GenServer

  def insert_new(name, query) do
    :ets.insert_new(__MODULE__, {name, query})
  end

  def fetch(name) do
    try do
      :ets.lookup_element(__MODULE__, name, 2)
    rescue
      ArgumentError ->
        :error
    else
      query ->
        {:ok, query}
    end
  end

  def delete(name, query) do
    :ets.delete_object(__MODULE__, {name, query})
  end

  def start_link() do
    GenServer.start_link(__MODULE__, __MODULE__, [name: __MODULE__])
  end

  def init(tab) do
    {:ok, :ets.new(tab, [:named_table, :public])}
  end
end

defmodule PokemonBattle.ClusterTables do
  use GenServer

  @tables [
    :pokemon_battle_battle_nodes,
    :pokemon_battle_exchange_rooms,
    :pokemon_battle_exchange_members
  ]

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    ensure_tables!()
    {:ok, %{}}
  end

  def ensure_tables! do
    Enum.each(@tables, &ensure_table!/1)
    :ok
  end

  def ensure_tables do
    GenServer.call(__MODULE__, :ensure_tables)
  end

  @impl true
  def handle_call(:ensure_tables, _from, state) do
    ensure_tables!()
    {:reply, :ok, state}
  end

  defp ensure_table!(tabla) do
    case :ets.whereis(tabla) do
      :undefined ->
        _ =
          :ets.new(tabla, [
            :named_table,
            :public,
            :set,
            read_concurrency: true,
            write_concurrency: true
          ])

        :ok

      _ ->
        :ok
    end
  end
end

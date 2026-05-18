defmodule PokemonBattle.SupervisorBatallas do
  use DynamicSupervisor

  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def crear_batalla(id, jugador1, opts \\ []) do
    node = PokemonBattle.Cluster.nodo_para_crear_batalla(id)
    spec = {PokemonBattle.Batalla, {id, jugador1, opts}}

    {result, actual_node} =
      if node == Node.self() do
        {DynamicSupervisor.start_child(__MODULE__, spec), Node.self()}
      else
        case :rpc.call(node, DynamicSupervisor, :start_child, [__MODULE__, spec]) do
          {:ok, pid} -> {{:ok, pid}, node}
          {:error, reason} -> {{:error, reason}, node}
          {:badrpc, _} -> {DynamicSupervisor.start_child(__MODULE__, spec), Node.self()}
        end
      end

    case result do
      {:ok, _pid} ->
        PokemonBattle.Cluster.registrar_batalla(id, actual_node)
        result

      _ ->
        result
    end
  end

  def crear_intercambio(codigo, creador) do
    spec = {PokemonBattle.Intercambio, {codigo, creador}}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def salas_activas do
    local = Registry.select(PokemonBattle.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
    remotas = PokemonBattle.Cluster.codigos_batalla()

    Enum.uniq(local ++ remotas)
    |> Enum.filter(&String.starts_with?(&1, "B-"))
    |> Enum.filter(&PokemonBattle.Cluster.batalla_activa?/1)
  end
end

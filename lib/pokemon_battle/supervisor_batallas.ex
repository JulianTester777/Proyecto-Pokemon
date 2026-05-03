defmodule PokemonBattle.SupervisorBatallas do
  use DynamicSupervisor

  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # -------- CREAR BATALLA --------
  def crear_batalla(id, jugador1) do
    spec = {PokemonBattle.Batalla, {id, jugador1}}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  # -------- CREAR INTERCAMBIO --------
  def crear_intercambio(codigo, creador) do
    spec = {PokemonBattle.Intercambio, {codigo, creador}}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end

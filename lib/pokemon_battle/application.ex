defmodule PokemonBattle.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: PokemonBattle.Registry},
      {PokemonBattle.ClusterTables, []},
      {PokemonBattle.SupervisorBatallas, []}
    ]

    opts = [strategy: :one_for_one, name: PokemonBattle.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

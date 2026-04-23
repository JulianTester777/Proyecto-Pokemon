defmodule PokemonBattle.Entrenador do
  @enforce_keys [:nombre]
  defstruct [
    :nombre,
    monedas: 0,
    monedas_acumuladas: 0,
    victorias: 0,
    coleccion: [],
    sobres_pendientes: [],
    equipos: []
  ]
end

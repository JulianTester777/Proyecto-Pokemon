defmodule PokemonBattle.Entrenador do
  @enforce_keys [:nombre]
  defstruct [
    :nombre,
    :clave,
    monedas: 0,
    monedas_acumuladas: 0,
    victorias: 0,
    coleccion: [],
    sobres_pendientes: [],
    equipos: [],
    equipo_actual: nil
  ]
end

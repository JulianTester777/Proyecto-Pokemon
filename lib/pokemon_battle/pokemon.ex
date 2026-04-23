defmodule PokemonBattle.Pokemon do
  @enforce_keys [:id, :especie, :dueño_original, :rareza]
  defstruct [
    :id,
    :especie,
    :dueño_original,
    :rareza,
    :ataque,
    :defensa,
    :velocidad,
    :movimientos,
    salud_actual: 100,
    salud_maxima: 100
  ]

  def crear_instancia(especie_id, datos, entrenador, rareza) do
    {min, max} =
      case rareza do
        "comun" -> {2, 8}
        "raro"  -> {10, 20}
        "epico" -> {25, 40}
      end

    factor = Enum.random(min..max) / 100

    %__MODULE__{
      id: :rand.uniform(100_000),
      especie: especie_id,
      dueño_original: entrenador,
      rareza: rareza,
      ataque: round(datos["ataque_base"] * (1 + factor)),
      defensa: round(datos["defensa_base"] * (1 + factor)),
      velocidad: round(datos["velocidad_base"] * (1 + factor)),
      movimientos: [],
      salud_actual: 100
    }
  end
end

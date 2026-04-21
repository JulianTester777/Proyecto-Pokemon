defmodule PokemonBattle.Pokemon do
  @moduledoc """
  Maneja la creación de instancias de Pokémon.
  """

  def crear_instancia(especie_id, datos, entrenador, rareza) do
    {min, max} =
      case rareza do
        :comun -> {2, 8}
        :raro  -> {10, 20}
        :epico -> {25, 40}
      end

    factor = Enum.random(min..max) / 100

    ataque_base = datos["ataque_base"]
    defensa_base = datos["defensa_base"]
    velocidad_base = datos["velocidad_base"]

    %{
      id: :rand.uniform(100_000),
      especie: especie_id,
      rareza: rareza,
      dueño_original: entrenador,
      ataque: round(ataque_base * (1 + factor)),
      defensa: round(defensa_base * (1 + factor)),
      velocidad: round(velocidad_base * (1 + factor)),
      salud: 100,
      movimientos: []
    }
  end
end

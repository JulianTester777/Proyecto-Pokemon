defmodule PokemonBattle.Pokemon do
  @moduledoc """
  Define la estructura de una instancia de Pokémon y la lógica de sus estadísticas.
  """
  defstruct [:id, :especie, :dueño_original, :rareza, :ataque, :defensa, :velocidad, :movimientos, salud_maxima: 100]

  def crear_instancia(especie_id, datos_base, dueño, rareza) do
    factor = calcular_factor_rareza(rareza)

    # Fórmulas oficiales del proyecto
    ataque = calcular_stat(datos_base["ataque_base"], factor)
    defensa = calcular_stat(datos_base["defensa_base"], factor)
    velocidad = calcular_stat(datos_base["velocidad_base"], factor)

    %__MODULE__{
      id: :rand.uniform(100_000),
      especie: especie_id,
      dueño_original: dueño,
      rareza: rareza,
      ataque: ataque,
      defensa: defensa,
      velocidad: velocidad,
      movimientos: []
    }
  end

  defp calcular_factor_rareza(:comun), do: Enum.random(2..8)
  defp calcular_factor_rareza(:raro), do: Enum.random(10..20)
  defp calcular_factor_rareza(:epico), do: Enum.random(25..40)

  defp calcular_stat(base, factor), do: round(base * (1 + factor / 100))
end

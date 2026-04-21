defmodule PokemonBattle.SistemaSobres do
  alias PokemonBattle.Pokemon

  @doc """
  Abre un sobre del tipo dado y retorna 3 Pokémon con movimientos asignados.
  """
  def abrir_sobre(entrenador_nombre, tipo_sobre, pokemon_base, todos_los_movimientos, tienda) do
    probabilidades = tienda[tipo_sobre]["probabilidades"]
    especies_disponibles = Map.keys(pokemon_base)

    Enum.map(1..3, fn _ ->
      especie_id = Enum.random(especies_disponibles)
      datos = pokemon_base[especie_id]

      rareza = sortear_rareza(probabilidades)

      pkm = Pokemon.crear_instancia(especie_id, datos, entrenador_nombre, rareza)
      pkm_con_tipos = Map.put(pkm, :tipos, datos["tipos"])
      asignar_movimientos(pkm_con_tipos, datos["tipos"], todos_los_movimientos)
    end)
  end

  @doc """
  Sortea rareza según probabilidades del tipo de sobre.
  """
  def sortear_rareza(probabilidades) do
    n = :rand.uniform(100)

    comun = probabilidades["comun"]
    raro  = probabilidades["comun"] + probabilidades["raro"]

    cond do
      n <= comun -> :comun
      n <= raro  -> :raro
      true       -> :epico
    end
  end

  defp asignar_movimientos(pkm, tipos, pool) do
    movs_tipo = Enum.flat_map(tipos, fn t -> pool[t] || [] end)
                |> Enum.shuffle()
                |> Enum.take(2)

    movs_extra = Map.values(pool)
                 |> List.flatten()
                 |> Enum.shuffle()

    final_movs = (movs_tipo ++ movs_extra)
                 |> Enum.uniq_by(fn m -> m["nombre"] end)
                 |> Enum.take(4)

    final_movs = if length(final_movs) < 4 do
      Map.values(pool)
      |> List.flatten()
      |> Enum.uniq_by(fn m -> m["nombre"] end)
      |> Enum.take(4)
    else
      final_movs
    end

    %{pkm | movimientos: final_movs}
  end
end

defmodule PokemonBattle.SistemaSobres do
  alias PokemonBattle.Pokemon

  def abrir_sobre(entrenador_nombre, pokemon_base, todos_los_movimientos) do
    especies_disponibles = Map.keys(pokemon_base)

    Enum.map(1..3, fn _ ->
      especie_id = Enum.random(especies_disponibles)
      datos = pokemon_base[especie_id]

      rareza = Enum.random([:comun, :raro, :epico])

      pkm = Pokemon.crear_instancia(especie_id, datos, entrenador_nombre, rareza)
      asignar_movimientos(pkm, datos["tipos"], todos_los_movimientos)
    end)
  end

  defp asignar_movimientos(pkm, tipos, pool) do
    # 2 movimientos del tipo del Pokémon (si existen)
    movs_tipo = Enum.flat_map(tipos, fn t -> pool[t] || [] end)
                |> Enum.shuffle()
                |> Enum.take(2)

    # Todos los movimientos del pool como relleno
    movs_extra = Map.values(pool)
                 |> List.flatten()
                 |> Enum.shuffle()

    # Combinar, quitar duplicados, garantizar exactamente 4
    final_movs = (movs_tipo ++ movs_extra)
                 |> Enum.uniq_by(fn m -> m["nombre"] end)
                 |> Enum.take(4)

    # Garantía: si por alguna razón hay menos de 4, rellenar con lo que haya
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

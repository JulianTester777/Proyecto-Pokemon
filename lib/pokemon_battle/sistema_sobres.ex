defmodule PokemonBattle.SistemaSobres do
  alias PokemonBattle.{Pokemon, Movimiento}

  def abrir_sobre(entrenador, tipo, especies, moves, tienda) do
    Enum.map(1..3, fn _ ->
      especie = Enum.random(especies)
      rareza = sortear_rareza(tipo, tienda)

      pkm =
        Pokemon.crear_instancia(
          especie,
          entrenador,
          String.to_atom(rareza)
        )

      movimientos = asignar_movimientos(especie.tipos, moves)

      %{pkm | movimientos: movimientos}
    end)
  end

  defp sortear_rareza(tipo, tienda) do
    probs = tienda[tipo]["probabilidades"]
    r = :rand.uniform(100)

    cond do
      r <= probs["comun"] -> "comun"
      r <= probs["comun"] + probs["raro"] -> "raro"
      true -> "epico"
    end
  end

  # ✅ CORRECTO 100%
  defp asignar_movimientos(tipos, pool) do
    tipos = Enum.map(tipos, &String.downcase/1)

    # 1. Movimientos del tipo del Pokémon
    elegidos_tipo =
      case tipos do
        [t1, t2] ->
          [
            Enum.random(Map.get(pool, t1, [])),
            Enum.random(Map.get(pool, t2, []))
          ]

        [t] ->
          Enum.take_random(Map.get(pool, t, []), 2)
      end

    # 2. Pool global
    todos =
      pool
      |> Map.values()
      |> List.flatten()

    # 3. Quitar duplicados
    restantes =
      Enum.reject(todos, fn m ->
        Enum.any?(elegidos_tipo, &(&1["nombre"] == m["nombre"]))
      end)

    # 4. Completar EXACTAMENTE 4
    faltan = 4 - length(elegidos_tipo)
    extra = Enum.take_random(restantes, faltan)

    final = elegidos_tipo ++ extra

    # 5. Convertir a struct
    Enum.map(final, fn m ->
      %Movimiento{
        nombre: m["nombre"],
        tipo: String.downcase(m["tipo"]),
        poder_base: m["poder_base"]
      }
    end)
  end
end

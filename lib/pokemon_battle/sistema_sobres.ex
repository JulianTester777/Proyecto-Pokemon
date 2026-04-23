defmodule PokemonBattle.SistemaSobres do
  alias PokemonBattle.{Pokemon, Movimiento}

  def abrir_sobre(entrenador, tipo, pokes_base, moves_base, tienda) do
    Enum.map(1..3, fn _ ->
      especie = Enum.random(pokes_base)
      rareza = sortear_rareza(tipo, tienda)

      pkm =
        Pokemon.crear_instancia(
          especie["especie"],
          especie,
          entrenador,
          String.to_atom(rareza)
        )

      movimientos = asignar_movimientos(especie["tipos"], moves_base)

      %{pkm | movimientos: movimientos}
    end)
  end

  # 🎯 PROBABILIDADES REALES
  defp sortear_rareza(tipo, tienda) do
    probs = tienda[tipo]["probabilidades"]
    r = :rand.uniform(100)

    cond do
      r <= probs["comun"] -> "comun"
      r <= probs["comun"] + probs["raro"] -> "raro"
      true -> "epico"
    end
  end

  defp asignar_movimientos(tipos, pool) do
  tipos = Enum.map(tipos, &String.downcase/1)

  # 🔹 Regla 1: asegurar movimientos del tipo
  movs_tipo =
    tipos
    |> Enum.flat_map(fn t -> Map.get(pool, t, []) end)

  elegidos_tipo =
    case tipos do
      [t1, t2] ->
        # mínimo 1 de cada tipo
        [
          Enum.random(Map.get(pool, t1, [])),
          Enum.random(Map.get(pool, t2, []))
        ]

      [_] ->
        # mínimo 2 del mismo tipo
        Enum.take_random(movs_tipo, 2)
    end

  # 🔹 Regla 2: completar con cualquiera
  todos =
    pool
    |> Map.values()
    |> List.flatten()

  restantes =
    todos
    |> Enum.reject(fn m -> Enum.any?(elegidos_tipo, &(&1["nombre"] == m["nombre"])) end)
    |> Enum.take_random(4 - length(elegidos_tipo))

  (elegidos_tipo ++ restantes)
  |> Enum.uniq_by(& &1["nombre"])
  |> Enum.take(4)
  |> Enum.map(fn m ->
    %PokemonBattle.Movimiento{
      nombre: m["nombre"],
      tipo: m["tipo"],
      poder_base: m["poder_base"]
    }
  end)
end
end

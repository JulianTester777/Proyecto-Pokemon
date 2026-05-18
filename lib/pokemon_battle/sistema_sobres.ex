defmodule PokemonBattle.SistemaSobres do
  alias PokemonBattle.{Movimiento, Pokemon}

  def abrir_sobre(entrenador, tipo, especies, moves, tienda) do
    Enum.map(1..3, fn _ ->
      especie = Enum.random(especies)
      rareza = sortear_rareza(tipo, tienda)

      pokemon =
        Pokemon.crear_instancia(
          especie,
          entrenador,
          String.to_atom(rareza)
        )

      movimientos = asignar_movimientos(especie.tipos || [], moves)
      %{pokemon | movimientos: movimientos}
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

  defp asignar_movimientos(tipos, pool) do
    tipos = Enum.map(List.wrap(tipos), &String.downcase/1)
    movs_por_tipo = pool |> Map.new(fn {k, v} -> {String.downcase(k), v} end)

    movimientos_tipo =
      case tipos do
        [t1, t2] when t1 == t2 ->
          Enum.take_random(Map.get(movs_por_tipo, t1, []), min(2, length(Map.get(movs_por_tipo, t1, []))))

        [t1, t2] ->
          [
            movimiento_aleatorio(movs_por_tipo[t1]),
            movimiento_aleatorio(movs_por_tipo[t2])
          ]
          |> Enum.reject(&is_nil/1)

        [t] ->
          Enum.take_random(Map.get(movs_por_tipo, t, []), min(2, length(Map.get(movs_por_tipo, t, []))))

        _ ->
          []
      end

    restantes =
      movs_por_tipo
      |> Map.values()
      |> List.flatten()
      |> Enum.reject(fn mov -> Enum.any?(movimientos_tipo, &(&1["nombre"] == mov["nombre"])) end)

    faltan = max(0, 4 - length(movimientos_tipo))
    extras = Enum.take_random(restantes, faltan)

    (movimientos_tipo ++ extras)
    |> Enum.uniq_by(& &1["nombre"])
    |> Enum.take(4)
    |> Enum.map(fn mov ->
      %Movimiento{
        nombre: mov["nombre"],
        tipo: String.downcase(mov["tipo"]),
        poder_base: mov["poder_base"]
      }
    end)
  end

  defp movimiento_aleatorio(nil), do: nil
  defp movimiento_aleatorio([]), do: nil
  defp movimiento_aleatorio(lista), do: Enum.random(lista)
end

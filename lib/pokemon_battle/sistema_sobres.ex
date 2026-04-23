defmodule PokemonBattle.SistemaSobres do
  alias PokemonBattle.{Pokemon, Movimiento, Persistencia}

  def abrir_sobre(entrenador, tipo, pokes, movs, tienda) do
    Enum.map(1..3, fn _ ->
      generar_pokemon(entrenador, pokes, movs)
    end)
  end

  def generar_pokemon(entrenador_nombre, especies, moves) do
    especie = Enum.random(especies)
    rareza = random_rareza()

    pkm =
      Pokemon.crear_instancia(
        especie["especie"],
        especie,
        entrenador_nombre,
        rareza
      )

    movimientos = generar_movimientos(especie["tipos"], moves)

    %{pkm | movimientos: movimientos}
  end

  defp random_rareza do
    r = :rand.uniform()

    cond do
      r <= 0.7 -> "comun"
      r <= 0.95 -> "raro"
      true -> "epico"
    end
  end

  defp generar_movimientos(tipos, pool) do
    movs_tipo =
      tipos
      |> Enum.flat_map(&Map.get(pool, &1, []))

    obligatorios =
      case tipos do
        [t1, t2] ->
          [Enum.random(Map.get(pool, t1)), Enum.random(Map.get(pool, t2))]

        [t] ->
          Enum.take_random(Map.get(pool, t), 2)
      end

    extras =
      pool
      |> Map.values()
      |> List.flatten()
      |> Enum.take_random(2)

    (obligatorios ++ extras)
    |> Enum.uniq_by(& &1["nombre"])
    |> Enum.take(4)
    |> Enum.map(fn m ->
      %Movimiento{
        nombre: m["nombre"],
        tipo: m["tipo"],
        poder_base: m["poder_base"]
      }
    end)
  end
end

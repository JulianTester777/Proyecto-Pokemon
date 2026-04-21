defmodule PokemonBattle.SistemaSobres do
  alias PokemonBattle.Pokemon

  @doc """
  Abre un sobre y genera 3 Pokémon con movimientos válidos.
  """
  def abrir_sobre(entrenador_nombre, tipo_sobre, pokemon_base, pool_movimientos, tienda) do
    probabilidades = tienda[tipo_sobre]["probabilidades"]
    especies = Map.keys(pokemon_base)

    Enum.map(1..3, fn _ ->
      especie_id = Enum.random(especies)
      datos = pokemon_base[especie_id]

      tipos = datos["tipos"]
      rareza = sortear_rareza(probabilidades)

      pkm =
        Pokemon.crear_instancia(especie_id, datos, entrenador_nombre, rareza)

      asignar_movimientos(pkm, tipos, pool_movimientos)
    end)
  end

  @doc """
  Sortea la rareza según probabilidades.
  """
  def sortear_rareza(probabilidades) do
    n = :rand.uniform(100)

    comun = probabilidades["comun"]
    raro  = comun + probabilidades["raro"]

    cond do
      n <= comun -> :comun
      n <= raro  -> :raro
      true       -> :epico
    end
  end

  @doc """
  Asigna 4 movimientos cumpliendo TODAS las reglas del enunciado.
  """
  defp asignar_movimientos(pkm, tipos, pool) do
    # 🔹 Paso 1: movimientos obligatorios por tipo
    movs_tipo =
      case tipos do
        [tipo] ->
          pool
          |> Map.get(tipo, [])
          |> Enum.shuffle()
          |> Enum.take(2)

        [t1, t2] ->
          m1 = Enum.random(Map.get(pool, t1, []))
          m2 = Enum.random(Map.get(pool, t2, []))
          [m1, m2]
      end

    # 🔹 Paso 2: pool global
    pool_global =
      pool
      |> Map.values()
      |> List.flatten()

    # 🔹 Paso 3: evitar repetidos
    usados = MapSet.new(movs_tipo)

    disponibles =
      pool_global
      |> Enum.reject(fn m -> MapSet.member?(usados, m) end)

    # 🔹 Paso 4: completar hasta 4
    faltantes = 4 - length(movs_tipo)

    movs_extra =
      disponibles
      |> Enum.shuffle()
      |> Enum.take(faltantes)

    movimientos_finales = movs_tipo ++ movs_extra

    %{pkm | movimientos: movimientos_finales}
  end
end

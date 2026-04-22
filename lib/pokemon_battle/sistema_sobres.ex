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
      datos      = pokemon_base[especie_id]
      tipos      = datos["tipos"]
      rareza     = sortear_rareza(probabilidades)

      pkm = Pokemon.crear_instancia(especie_id, datos, entrenador_nombre, rareza)
      pkm_con_tipos = Map.put(pkm, :tipos, tipos)

      asignar_movimientos(pkm_con_tipos, tipos, pool_movimientos)
    end)
  end

  @doc """
  Sortea rareza según probabilidades del tipo de sobre.
  """
  def sortear_rareza(probabilidades) do
    n     = :rand.uniform(100)
    comun = probabilidades["comun"]
    raro  = comun + probabilidades["raro"]

    cond do
      n <= comun -> :comun
      n <= raro  -> :raro
      true       -> :epico
    end
  end

  @doc """
  Asigna 4 movimientos cumpliendo todas las reglas del enunciado.
  """
  defp asignar_movimientos(pkm, tipos, pool) do
    # Paso 1: movimientos obligatorios por tipo
    movs_tipo =
      case tipos do
        [tipo] ->
          # 1 tipo: tomar 2 movimientos de ese tipo
          pool
          |> Map.get(tipo, [])
          |> Enum.shuffle()
          |> Enum.take(2)

        [t1, t2] ->
          # 2 tipos: tomar 1 de cada tipo (fix: Enum.take en vez de Enum.random)
          m1 = pool |> Map.get(t1, []) |> Enum.shuffle() |> Enum.take(1)
          m2 = pool |> Map.get(t2, []) |> Enum.shuffle() |> Enum.take(1)
          m1 ++ m2

        _ ->
          []
      end

    # Paso 2: pool global aplanado
    pool_global = pool |> Map.values() |> List.flatten()

    # Paso 3: evitar repetidos comparando por nombre (fix: MapSet de nombres)
    usados = MapSet.new(movs_tipo, fn m -> m["nombre"] end)

    disponibles =
      pool_global
      |> Enum.reject(fn m -> MapSet.member?(usados, m["nombre"]) end)
      |> Enum.shuffle()

    # Paso 4: completar hasta exactamente 4
    faltantes  = 4 - length(movs_tipo)
    movs_extra = Enum.take(disponibles, faltantes)

    movimientos_finales = movs_tipo ++ movs_extra

    %{pkm | movimientos: movimientos_finales}
  end
end

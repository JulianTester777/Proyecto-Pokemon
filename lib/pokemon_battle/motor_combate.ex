defmodule PokemonBattle.MotorCombate do
  @tabla %{
    "fuego" => ["planta", "hielo", "bicho"],
    "agua" => ["fuego", "roca", "tierra"],
    "planta" => ["agua", "roca", "tierra"],
    "electrico" => ["agua", "volador"],
    "roca" => ["fuego", "hielo", "volador", "bicho"]
  }

  def calcular_daño(atacante, defensor, movimiento, tipos_atacante, tipos_defensor) do
    tipos_atacante = normalizar_tipos(tipos_atacante)
    tipos_defensor = normalizar_tipos(tipos_defensor)
    tipo_mov = normalizar_tipo(movimiento.tipo)
    poder = movimiento.poder_base || 0

    daño_base =
      trunc((poder * (atacante.ataque / defensor.defensa)) / 5 + 2)

    efectividad = calcular_efectividad(tipo_mov, tipos_defensor)
    stab = calcular_stab(tipo_mov, tipos_atacante)
    random = :rand.uniform() * (1.0 - 0.85) + 0.85

    trunc(daño_base * efectividad * stab * random)
    |> max(1)
  end

  defp normalizar_tipos(tipos) when is_list(tipos) do
    Enum.map(tipos, &normalizar_tipo/1)
  end

  defp normalizar_tipos(_), do: []

  defp normalizar_tipo(nil), do: ""
  defp normalizar_tipo(tipo) when is_atom(tipo), do: tipo |> Atom.to_string() |> String.downcase()
  defp normalizar_tipo(tipo) when is_binary(tipo), do: String.downcase(tipo)
  defp normalizar_tipo(tipo), do: tipo |> to_string() |> String.downcase()

  defp calcular_efectividad(tipo_mov, tipos_def) do
    Enum.reduce(tipos_def, 1.0, fn tipo_def, acc ->
      cond do
        fuerte?(tipo_mov, tipo_def) -> acc * 2.0
        fuerte?(tipo_def, tipo_mov) -> acc * 0.5
        true -> acc
      end
    end)
  end

  defp fuerte?(tipo1, tipo2) do
    Map.get(@tabla, String.downcase(tipo1), [])
    |> Enum.member?(String.downcase(tipo2))
  end

  defp calcular_stab(tipo_mov, tipos_atacante) do
    if tipo_mov in tipos_atacante, do: 1.5, else: 1.0
  end
end

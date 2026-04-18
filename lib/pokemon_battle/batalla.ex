defmodule PokemonBattle.Batalla do
  @doc """
  Simula un ataque de un Pokémon a otro.
  """
  def atacar(atacante, defensor, nombre_movimiento) do
    # 1. Buscar el movimiento en la lista del atacante
    movimiento = Enum.find(atacante.movimientos, fn m -> m["nombre"] == nombre_movimiento end)

    if movimiento do
      IO.puts("¡#{atacante.especie} usa #{nombre_movimiento}!")

      # 2. Fórmula de daño: ((Poder + Ataque) - (Defensa / 2))
      # Usamos max(1, ...) para que siempre haga al menos 1 de daño
      daño = max(1, (movimiento["poder_base"] + atacante.ataque) - round(defensor.defensa / 2))

      nueva_salud = defensor.salud_maxima - daño
      IO.puts("¡Es muy eficaz! Hizo #{daño} de daño.")

      # Retornamos al defensor actualizado
      %{defensor | salud_maxima: max(0, nueva_salud)}
    else
      IO.puts("#{atacante.especie} no conoce ese movimiento.")
      defensor
    end
  end
end

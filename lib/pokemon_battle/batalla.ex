defmodule PokemonBattle.Batalla do
  alias PokemonBattle.MotorCombate

  def atacar(atacante, defensor, movimiento, tipos_atacante, tipos_defensor) do
    daño =
      MotorCombate.calcular_daño(
        atacante,
        defensor,
        movimiento,
        tipos_atacante,
        tipos_defensor
      )

    nueva_salud = max(0, defensor.salud_actual - daño)

    IO.puts("Daño: #{daño}")

    %{defensor | salud_actual: nueva_salud}
  end
end

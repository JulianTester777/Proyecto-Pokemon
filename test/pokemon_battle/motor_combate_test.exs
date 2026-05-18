defmodule PokemonBattle.MotorCombateTest do
  use ExUnit.Case, async: false

  alias PokemonBattle.{Movimiento, MotorCombate, Pokemon}

  defp pokemon(attrs) do
    attrs = Enum.into(attrs, %{})

    struct(Pokemon, %{
      id: Map.get(attrs, :id, :erlang.unique_integer([:positive])),
      especie: Map.get(attrs, :especie, "pikachu"),
      dueño_original: Map.get(attrs, :dueño_original, "ana"),
      rareza: Map.get(attrs, :rareza, :comun),
      ataque: Map.get(attrs, :ataque, 50),
      defensa: Map.get(attrs, :defensa, 50),
      velocidad: Map.get(attrs, :velocidad, 50),
      tipos: Map.get(attrs, :tipos, [])
    })
  end

  test "missing attacker types do not crash" do
    attacker = pokemon(ataque: 63, tipos: nil)
    defender = pokemon(defensa: 70, tipos: ["agua"])
    move = %Movimiento{nombre: "impactrueno", tipo: "electrico", poder_base: 65}

    damage = MotorCombate.calcular_daño(attacker, defender, move, nil, defender.tipos)

    assert is_integer(damage)
    assert damage > 0
  end

  test "missing defender types do not crash" do
    attacker = pokemon(ataque: 63, tipos: ["electrico"])
    defender = pokemon(defensa: 70, tipos: nil)
    move = %Movimiento{nombre: "placaje", tipo: "normal", poder_base: 35}

    damage = MotorCombate.calcular_daño(attacker, defender, move, attacker.tipos, nil)

    assert is_integer(damage)
    assert damage > 0
  end

  test "damage respects strong weak and neutral type relations" do
    attacker = pokemon(ataque: 100, defensa: 100, tipos: ["normal"])
    defender = pokemon(defensa: 100, tipos: ["planta"])

    strong = MotorCombate.calcular_daño(attacker, defender, %Movimiento{nombre: "fuego", tipo: "fuego", poder_base: 50}, attacker.tipos, defender.tipos)
    neutral = MotorCombate.calcular_daño(attacker, defender, %Movimiento{nombre: "normal", tipo: "normal", poder_base: 50}, attacker.tipos, defender.tipos)
    weak = MotorCombate.calcular_daño(attacker, defender, %Movimiento{nombre: "planta", tipo: "planta", poder_base: 50}, attacker.tipos, ["fuego"])

    assert strong > neutral
    assert neutral > weak
  end
end

defmodule PokemonBattle.PokemonTest do
  use ExUnit.Case, async: false

  alias PokemonBattle.{Especie, Pokemon}

  test "defaults tipos to an empty list" do
    pokemon = %Pokemon{
      id: 1,
      especie: "charmander",
      dueño_original: "ash",
      rareza: :comun
    }

    assert pokemon.tipos == []
  end

  test "creates instances carrying species tipos" do
    especie = %Especie{
      especie: "charmander",
      tipos: ["fuego"],
      ataque_base: 52,
      defensa_base: 43,
      velocidad_base: 65
    }

    pokemon = Pokemon.crear_instancia(especie, "ash", :comun)

    assert pokemon.tipos == ["fuego"]
    assert pokemon.salud_actual == 100
    assert pokemon.salud_maxima == 100
  end
end

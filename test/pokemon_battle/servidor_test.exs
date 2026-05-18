defmodule PokemonBattle.ServidorTest do
  use ExUnit.Case, async: false

  alias PokemonBattle.{Batalla, Entrenador, Especie, Pokemon, Servidor}

  setup do
    codigo = "B-#{System.unique_integer([:positive])}"

    on_exit(fn ->
      case Registry.lookup(PokemonBattle.Registry, codigo) do
        [{pid, _}] -> GenServer.stop(pid, :normal)
        [] -> :ok
      end
    end)

    {:ok, codigo: codigo}
  end

  defp entrenador(nombre, with_pokemon \\ true) do
    coleccion =
      if with_pokemon do
        [
          Pokemon.crear_instancia(
            %Especie{
              especie: "bulbasaur",
              tipos: ["planta"],
              ataque_base: 49,
              defensa_base: 49,
              velocidad_base: 45
            },
            nombre,
            :comun
          )
        ]
      else
        []
      end

    equipo_ids = Enum.map(coleccion, & &1.id)

    %Entrenador{
      nombre: nombre,
      monedas: 0,
      monedas_acumuladas: 0,
      victorias: 0,
      coleccion: coleccion,
      sobres_pendientes: [],
      equipos: if(with_pokemon, do: [%{"nombre" => "default", "pokemon_ids" => equipo_ids}], else: []),
      equipo_actual: if(with_pokemon, do: "default", else: nil)
    }
  end

  test "crear_batalla and unirse_batalla work for valid trainers", %{codigo: _codigo} do
    assert {:ok, codigo} = Servidor.crear_batalla(entrenador("ana"))
    assert {:ok, msg} = Servidor.unirse_batalla(codigo, entrenador("luis"))
    assert msg =~ "luis"

    estado = Batalla.estado(codigo)
    assert map_size(estado.jugadores) == 2

    case Registry.lookup(PokemonBattle.Registry, codigo) do
      [{pid, _}] -> GenServer.stop(pid, :normal)
      [] -> :ok
    end
  end

  test "battle helpers reject empty teams with readable errors", %{codigo: codigo} do
    assert {:error, msg} = Servidor.crear_batalla(entrenador("ana", false))
    assert msg =~ "usable"

    assert {:error, msg2} = Servidor.unirse_batalla(codigo, entrenador("luis", false))
    assert msg2 =~ "usable"
  end

  test "unirse_batalla reports missing battle codes for eligible trainers", %{codigo: _codigo} do
    assert {:error, msg} = Servidor.unirse_batalla("B-999999", entrenador("luis"))
    assert msg =~ "No existe una batalla"
  end
end

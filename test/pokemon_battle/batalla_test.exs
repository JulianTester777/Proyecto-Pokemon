defmodule PokemonBattle.BatallaTest do
  use ExUnit.Case, async: false

  alias PokemonBattle.{Batalla, Entrenador, Especie, Pokemon}

  setup do
    Process.flag(:trap_exit, true)
    codigo = "B-#{System.unique_integer([:positive])}"

    on_exit(fn ->
      case Registry.lookup(PokemonBattle.Registry, codigo) do
        [{pid, _}] -> if Process.alive?(pid), do: GenServer.stop(pid, :normal), else: :ok
        _ -> :ok
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
              especie: "charmander",
              tipos: ["fuego"],
              ataque_base: 52,
              defensa_base: 43,
              velocidad_base: 65
            },
            nombre,
            :comun
          )
        ]
      else
        []
      end

    %Entrenador{
      nombre: nombre,
      monedas: 0,
      monedas_acumuladas: 0,
      victorias: 0,
      coleccion: coleccion,
      sobres_pendientes: [],
      equipos: []
    }
  end

  test "start_link rejects empty teams with a readable error", %{codigo: codigo} do
    assert {:error, reason} = Batalla.start_link({codigo, entrenador("ana", false)})
    assert to_string(reason) =~ "usable"
  end

  test "unirse rejects empty teams and keeps the battle stable", %{codigo: codigo} do
    assert {:ok, _pid} = Batalla.start_link({codigo, entrenador("ana")})

    assert {:error, reason} = Batalla.unirse(codigo, entrenador("luis", false))
    assert to_string(reason) =~ "usable"

    estado = Batalla.estado(codigo)
    assert map_size(estado.jugadores) == 1
  end

  test "valid trainers can join the waiting battle", %{codigo: codigo} do
    assert {:ok, _pid} = Batalla.start_link({codigo, entrenador("ana")})
    assert :ok = Batalla.unirse(codigo, entrenador("luis"))

    estado = Batalla.estado(codigo)
    assert map_size(estado.jugadores) == 2
    assert estado.turno == 1
  end
end

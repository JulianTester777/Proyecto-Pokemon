defmodule PokemonBattle.GestorEntrenadoresTest do
  use ExUnit.Case, async: false

  alias PokemonBattle.{Entrenador, GestorEntrenadores, Movimiento, Pokemon}

  setup do
    dir = Path.join(System.tmp_dir!(), "pokemon-battle-#{System.unique_integer([:positive])}")
    File.rm_rf!(dir)
    File.mkdir_p!(dir)

    path = Path.join(dir, "trainers.json")

    on_exit(fn -> File.rm_rf!(dir) end)

    {:ok, path: path}
  end

  test "loads legacy trainer data without tipos", %{path: path} do
    legacy = [
      %{
        "nombre" => "ana",
        "monedas" => 0,
        "monedas_acumuladas" => 0,
        "victorias" => 0,
        "coleccion" => [
          %{
            "id" => 7,
            "especie" => "charmander",
            "rareza" => "comun",
            "ataque" => 53,
            "defensa" => 44,
            "velocidad" => 66,
            "dueño_original" => "ana",
            "movimientos" => [
              %{"nombre" => "ascuas", "tipo" => "fuego", "poder_base" => 30}
            ]
          }
        ],
        "sobres_pendientes" => [],
        "equipos" => []
      }
    ]

    File.write!(path, Jason.encode!(legacy))

    [trainer] = GestorEntrenadores.cargar_todos(path)
    [pokemon] = trainer.coleccion

    assert pokemon.tipos == []
    assert pokemon.movimientos == [%Movimiento{nombre: "ascuas", tipo: "fuego", poder_base: 30}]
  end

  test "saving a trainer writes tipos back out", %{path: path} do
    pokemon = %Pokemon{
      id: 9,
      especie: "charmander",
      dueño_original: "ana",
      rareza: :comun,
      ataque: 53,
      defensa: 44,
      velocidad: 66,
      tipos: ["fuego"],
      movimientos: [%Movimiento{nombre: "ascuas", tipo: "fuego", poder_base: 30}]
    }

    trainer = %Entrenador{
      nombre: "ana",
      monedas: 0,
      monedas_acumuladas: 0,
      victorias: 0,
      coleccion: [pokemon],
      sobres_pendientes: [],
      equipos: []
    }

    assert :ok = GestorEntrenadores.guardar_entrenador(trainer, path)

    [decoded] = Jason.decode!(File.read!(path))
    [saved_pokemon] = decoded["coleccion"]

    assert saved_pokemon["tipos"] == ["fuego"]
    assert saved_pokemon["movimientos"] == [%{"nombre" => "ascuas", "tipo" => "fuego", "poder_base" => 30}]
  end
end

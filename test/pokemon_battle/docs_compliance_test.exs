defmodule PokemonBattle.DocsComplianceTest do
  use ExUnit.Case, async: false

  alias PokemonBattle.{Batalla, Entrenador, GestorEntrenadores, GestorSalas, Movimiento, Pokemon, SistemaSobres}

  @trainers_file "data/trainers.json"

  setup do
    backup_dir = Path.join(System.tmp_dir!(), "pokemon-battle-backup-#{System.unique_integer([:positive])}")
    File.mkdir_p!(backup_dir)
    backup = Path.join(backup_dir, "trainers.json")
    File.cp!(@trainers_file, backup)

    on_exit(fn ->
      case Registry.lookup(PokemonBattle.Registry, "B-test-1") do
        [{pid, _}] -> if Process.alive?(pid), do: GenServer.stop(pid, :normal)
        _ -> :ok
      end

      File.cp!(backup, @trainers_file)
      File.rm_rf!(backup_dir)
    end)

    {:ok, backup: backup}
  end

  defp trainer_fixture(nombre, clave, pokemon_list, opts \\ []) do
    %Entrenador{
      nombre: nombre,
      clave: clave,
      monedas: Keyword.get(opts, :monedas, 0),
      monedas_acumuladas: Keyword.get(opts, :monedas_acumuladas, 0),
      victorias: Keyword.get(opts, :victorias, 0),
      coleccion: pokemon_list,
      sobres_pendientes: Keyword.get(opts, :sobres_pendientes, []),
      equipos: Keyword.get(opts, :equipos, []),
      equipo_actual: Keyword.get(opts, :equipo_actual)
    }
  end

  defp high_power_pokemon(id, especie, nombre_entrenador, tipos, velocidad) do
    %Pokemon{
      id: id,
      especie: especie,
      dueño_original: nombre_entrenador,
      rareza: :epico,
      ataque: 1_000,
      defensa: 10,
      velocidad: velocidad,
      tipos: tipos,
      movimientos: [
        %Movimiento{nombre: "golpe", tipo: hd(tipos), poder_base: 100}
      ],
      salud_actual: 100,
      salud_maxima: 100
    }
  end

  test "login creates trainer with password and a basic pack" do
    entrenador = GestorEntrenadores.iniciar_sesion("maria", "secreto")

    assert %Entrenador{clave: "secreto", sobres_pendientes: sobres} = entrenador
    assert length(sobres) == 1
    assert GestorEntrenadores.buscar_entrenador("maria").clave == "secreto"
  end

  test "team management can create, use, add and remove pokemon" do
    p1 = high_power_pokemon(1, "charmander", "ana", ["fuego"], 70)
    p2 = high_power_pokemon(2, "squirtle", "ana", ["agua"], 60)
    trainer = trainer_fixture("ana", "1234", [p1, p2])
    :ok = GestorEntrenadores.guardar_entrenador(trainer)

    loaded = GestorEntrenadores.buscar_entrenador("ana")
    assert {:ok, updated} = GestorEntrenadores.crear_equipo(loaded, "ofensivo", "1,2")
    assert length(updated.equipos) == 1

    p3 = high_power_pokemon(3, "bulbasaur", "ana", ["planta"], 50)
    trainer2 = %{updated | coleccion: updated.coleccion ++ [p3]}
    :ok = GestorEntrenadores.guardar_entrenador(trainer2)

    loaded2 = GestorEntrenadores.buscar_entrenador("ana")
    assert {:ok, updated3} = GestorEntrenadores.agregar_pokemon_equipo(loaded2, "ofensivo", 3)
    assert Enum.at(updated3.equipos, 0)["pokemon_ids"] == [1, 2, 3]

    assert {:ok, updated4} = GestorEntrenadores.quitar_pokemon_equipo(updated3, "ofensivo", 2)
    assert Enum.at(updated4.equipos, 0)["pokemon_ids"] == [1, 3]

    assert {:ok, updated5} = GestorEntrenadores.usar_equipo(updated4, "ofensivo")
    assert updated5.equipo_actual == "ofensivo"
  end

  test "opening a pack creates three pokemon with four unique moves and matching owner" do
    especies = PokemonBattle.Persistencia.cargar_especies("data/pokemon.json")
    moves = PokemonBattle.Persistencia.cargar_datos("data/moves.json")
    tienda = PokemonBattle.Persistencia.cargar_datos("data/tienda.json")

    pokes = SistemaSobres.abrir_sobre("ana", "basico", especies, moves, tienda)

    species_by_name = PokemonBattle.Persistencia.cargar_especies("data/pokemon.json") |> Map.new(&{&1.especie, &1})

    assert length(pokes) == 3
    assert Enum.all?(pokes, &(&1.dueño_original == "ana"))
    assert Enum.all?(pokes, &(length(&1.movimientos) == 4))
    assert Enum.all?(pokes, fn poke -> Enum.uniq_by(poke.movimientos, & &1.nombre) == poke.movimientos end)
    assert Enum.all?(pokes, fn poke ->
      especie = species_by_name[poke.especie]
      tipos = Enum.map(especie.tipos, &String.downcase/1)
      tipos_movs = Enum.map(poke.movimientos, &String.downcase(&1.tipo))

      case tipos do
        [tipo] -> Enum.count(tipos_movs, &(&1 == tipo)) >= 2
        [t1, t2] -> Enum.count(tipos_movs, &(&1 == t1)) >= 1 and Enum.count(tipos_movs, &(&1 == t2)) >= 1
        _ -> true
      end
    end)
  end

  test "battle rewards coins and respects speed order" do
    p1 = high_power_pokemon(10, "charmander", "ana", ["fuego"], 120)
    p2 = high_power_pokemon(20, "squirtle", "luis", ["agua"], 40)

    :ok = GestorEntrenadores.guardar_entrenador(trainer_fixture("ana", "1234", [p1]))
    :ok = GestorEntrenadores.guardar_entrenador(trainer_fixture("luis", "1234", [p2]))

    {:ok, _pid} = Batalla.start_link({"B-test-1", GestorEntrenadores.buscar_entrenador("ana")})
    assert :ok = Batalla.unirse("B-test-1", GestorEntrenadores.buscar_entrenador("luis"))

    assert :esperando = Batalla.atacar("B-test-1", "ana", "golpe")
    assert :ok = Batalla.atacar("B-test-1", "luis", "golpe")

    estado = Batalla.estado("B-test-1")
    assert estado.ganador == "ana"
    assert estado.jugadores["ana"].activo.salud_actual == 100
    assert estado.jugadores["luis"].activo.salud_actual == 0

    ana = GestorEntrenadores.cargar_todos() |> Enum.find(&(&1.nombre == "ana"))
    luis = GestorEntrenadores.cargar_todos() |> Enum.find(&(&1.nombre == "luis"))
    assert ana.monedas == 100
    assert luis.monedas == 30

    [{pid, _}] = Registry.lookup(PokemonBattle.Registry, "B-test-1")
    GenServer.stop(pid, :normal)
  end

  test "exchange rooms swap pokemon and preserve ids and owners" do
    p1 = high_power_pokemon(101, "charmander", "ana", ["fuego"], 70)
    p2 = high_power_pokemon(202, "squirtle", "luis", ["agua"], 60)

    :ok = GestorEntrenadores.guardar_entrenador(trainer_fixture("ana", "1234", [p1]))
    :ok = GestorEntrenadores.guardar_entrenador(trainer_fixture("luis", "1234", [p2]))

    assert {:ok, codigo} = GestorSalas.crear_sala_intercambio("ana")
    assert {:ok, _} = GestorSalas.unirse_sala_intercambio(codigo, "luis")
    assert {:ok, _} = GestorSalas.ofrecer_pokemon(codigo, "ana", 101)
    assert {:ok, _} = GestorSalas.ofrecer_pokemon(codigo, "luis", 202)
    assert {:ok, _} = GestorSalas.confirmar_intercambio(codigo, "ana")
    assert {:ok, _} = GestorSalas.confirmar_intercambio(codigo, "luis")

    ana = GestorEntrenadores.cargar_todos() |> Enum.find(&(&1.nombre == "ana"))
    luis = GestorEntrenadores.cargar_todos() |> Enum.find(&(&1.nombre == "luis"))
    assert ana.coleccion |> hd() |> Map.get(:id) == 202
    assert luis.coleccion |> hd() |> Map.get(:id) == 101
    assert hd(ana.coleccion).dueño_original == "luis"
    assert hd(luis.coleccion).dueño_original == "ana"
  end

  test "perfil shows correct trainer info" do
  :ok = GestorEntrenadores.guardar_entrenador(
    trainer_fixture("ana", "1234", [], monedas: 150, victorias: 3)
  )
  ana = GestorEntrenadores.buscar_entrenador("ana")
  assert ana.monedas == 150
  assert ana.victorias == 3
  assert ana.nombre == "ana"
end

test "clasificacion orders by victories then by accumulated coins" do
  :ok = GestorEntrenadores.guardar_entrenador(
    trainer_fixture("ana", "1234", [], victorias: 5, monedas_acumuladas: 500)
  )
  :ok = GestorEntrenadores.guardar_entrenador(
    trainer_fixture("luis", "1234", [], victorias: 5, monedas_acumuladas: 300)
  )
  :ok = GestorEntrenadores.guardar_entrenador(
    trainer_fixture("pedro", "1234", [], victorias: 3, monedas_acumuladas: 1000)
  )

  entrenadores = GestorEntrenadores.cargar_todos()
  clasificacion = GestorEntrenadores.clasificacion(entrenadores)

  nombres = Enum.map(clasificacion, fn {_, e} -> e.nombre end)
  pos_ana = Enum.find_index(nombres, &(&1 == "ana"))
  pos_luis = Enum.find_index(nombres, &(&1 == "luis"))
  pos_pedro = Enum.find_index(nombres, &(&1 == "pedro"))

  assert pos_ana < pos_luis
  assert pos_luis < pos_pedro
end

test "cannot create team with duplicate pokemon ids" do
  p1 = high_power_pokemon(1, "charmander", "ana", ["fuego"], 70)
  trainer = trainer_fixture("ana", "1234", [p1])
  :ok = GestorEntrenadores.guardar_entrenador(trainer)

  loaded = GestorEntrenadores.buscar_entrenador("ana")
  assert {:error, _} = GestorEntrenadores.crear_equipo(loaded, "duplicado", "1,1")
end


test "cannot create team with more than 3 pokemon" do
  p1 = high_power_pokemon(1, "charmander", "ana", ["fuego"], 70)
  p2 = high_power_pokemon(2, "squirtle", "ana", ["agua"], 60)
  p3 = high_power_pokemon(3, "bulbasaur", "ana", ["planta"], 50)
  p4 = high_power_pokemon(4, "charmander", "ana", ["fuego"], 80)
  trainer = trainer_fixture("ana", "1234", [p1, p2, p3, p4])
  :ok = GestorEntrenadores.guardar_entrenador(trainer)

  loaded = GestorEntrenadores.buscar_entrenador("ana")
  assert {:error, _} = GestorEntrenadores.crear_equipo(loaded, "grande", "1,2,3,4")
end


end

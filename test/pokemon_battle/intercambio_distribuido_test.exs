defmodule PokemonBattle.IntercambioDistribuidoTest do
  use ExUnit.Case, async: false

  alias PokemonBattle.{Cluster, Entrenador, GestorEntrenadores, GestorSalas, Movimiento, Pokemon}

  @trainers_file "data/trainers.json"
  @cookie :pokemon_battle

  setup_all do
    ensure_local_node!()
    {:ok, handle, node} = start_remote_node()

    on_exit(fn ->
      stop_remote_node(handle)
    end)

    {:ok, peer_node: node}
  end

  setup do
    backup_dir =
      Path.join(
        System.tmp_dir!(),
        "pokemon-battle-distribuido-backup-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(backup_dir)
    backup = Path.join(backup_dir, "trainers.json")
    File.cp!(@trainers_file, backup)

    on_exit(fn ->
      cleanup_exchange_state()
      File.cp!(backup, @trainers_file)
      File.rm_rf!(backup_dir)
    end)

    {:ok, backup: backup}
  end

  defp ensure_local_node! do
    if not Node.alive?() do
      name = String.to_atom("pokemon-distribuido-#{System.unique_integer([:positive])}")
      {:ok, _pid} = Node.start(name, :shortnames)
    end

    Node.set_cookie(@cookie)
  end

  defp start_remote_node do
    name = String.to_atom("pokemon-peer-#{System.unique_integer([:positive])}")
    cookie = @cookie |> Atom.to_string() |> String.to_charlist()

    case start_peer_node(name, cookie) do
      {:ok, handle, node} ->
        bootstrap_remote_node(node)
        ensure_nodes_connected(node)
        {:ok, handle, node}

      {:error, reason} ->
        flunk("No pude levantar un nodo distribuido con :peer: #{inspect(reason)}")
    end
  end

  defp start_peer_node(name, cookie) do
    if function_exported?(:peer, :start_link, 1) do
      case :peer.start_link(%{
            name: name,
            args: [~c"-setcookie", cookie]
          }) do
        {:ok, peer, node} ->
          {:ok, {:peer, peer}, node}

        {:error, reason} ->
          {:error, reason}

        other ->
          {:error, other}
      end
    else
      {:error, :peer_unavailable}
    end
  end

  defp bootstrap_remote_node(node) do
    _ = :rpc.call(node, :code, :add_paths, [:code.get_path()])
    assert {:ok, _} = :rpc.call(node, Application, :ensure_all_started, [:pokemon_battle])
  end

  defp stop_remote_node({:peer, peer}) do
    if function_exported?(:peer, :stop, 1) and Process.alive?(peer) do
      try do
        :peer.stop(peer)
      rescue
        _ -> :ok
      catch
        _, _ -> :ok
      end
    end
  end

  defp stop_remote_node({:slave, node}) do
    if function_exported?(:slave, :stop, 1) do
      try do
        :slave.stop(node)
      rescue
        _ -> :ok
      catch
        _, _ -> :ok
      end
    end
  end

  defp ensure_nodes_connected(node) do
    assert :pong = Node.ping(node)
    assert true = :rpc.call(node, Node, :connect, [Node.self()])
  end

  defp cleanup_exchange_state do
    Enum.each(GestorSalas.salas_activas(), &stop_exchange_room/1)
    Enum.each(Cluster.codigos_sala_intercambio(), &Cluster.liberar_sala_intercambio/1)
    Enum.each(["ana", "luis"], &Cluster.liberar_miembro_intercambio/1)
  end

  defp stop_exchange_room(codigo) do
    case Cluster.nodo_de_sala_intercambio(codigo) do
      nil ->
        :ok

      node ->
        case :rpc.call(node, Registry, :lookup, [PokemonBattle.Registry, codigo]) do
          [{pid, _}] ->
            _ = :rpc.call(node, GenServer, :stop, [pid, :normal])
            :ok

          _ ->
            :ok
        end
    end
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

  test "two connected nodes can create, join, offer and confirm an exchange room", %{
    peer_node: peer_node
  } do
    :ok =
      GestorEntrenadores.guardar_entrenador(
        trainer_fixture("ana", "1234", [
          high_power_pokemon(101, "charmander", "ana", ["fuego"], 70)
        ])
      )

    :ok =
      GestorEntrenadores.guardar_entrenador(
        trainer_fixture("luis", "1234", [
          high_power_pokemon(202, "squirtle", "luis", ["agua"], 60)
        ])
      )

    assert {:ok, codigo} = :rpc.call(peer_node, GestorSalas, :crear_sala_intercambio, ["ana"])
    assert String.starts_with?(codigo, "IC-")
    assert codigo in GestorSalas.salas_activas()
    assert codigo in :rpc.call(peer_node, GestorSalas, :salas_activas, [])

    assert {:ok, _} = GestorSalas.unirse_sala_intercambio(codigo, "luis")
    assert {:ok, _} = :rpc.call(peer_node, GestorSalas, :ofrecer_pokemon, [codigo, "ana", 101])
    assert {:ok, _} = GestorSalas.ofrecer_pokemon(codigo, "luis", 202)

    assert {:ok, msg} =
    :rpc.call(peer_node, GestorSalas, :confirmar_intercambio, [codigo, "ana"])
    assert String.contains?(msg, "confirmado")

    assert {:ok, "[Intercambio completado] ana ↔ luis"} =
             GestorSalas.confirmar_intercambio(codigo, "luis")

    ana = GestorEntrenadores.buscar_entrenador("ana")
    luis = GestorEntrenadores.buscar_entrenador("luis")

    assert Enum.map(ana.coleccion, & &1.id) == [202]
    assert Enum.map(luis.coleccion, & &1.id) == [101]
    refute codigo in GestorSalas.salas_activas()
    refute codigo in :rpc.call(peer_node, GestorSalas, :salas_activas, [])
  end

  test "cancel clears visibility on both nodes immediately", %{peer_node: peer_node} do
    :ok =
      GestorEntrenadores.guardar_entrenador(
        trainer_fixture("ana", "1234", [
          high_power_pokemon(301, "charmander", "ana", ["fuego"], 70)
        ])
      )

    :ok =
      GestorEntrenadores.guardar_entrenador(
        trainer_fixture("luis", "1234", [
          high_power_pokemon(302, "squirtle", "luis", ["agua"], 60)
        ])
      )

    assert {:ok, codigo} = :rpc.call(peer_node, GestorSalas, :crear_sala_intercambio, ["ana"])
    assert {:ok, _} = GestorSalas.unirse_sala_intercambio(codigo, "luis")
    assert codigo in GestorSalas.salas_activas()
    assert codigo in :rpc.call(peer_node, GestorSalas, :salas_activas, [])

    assert {:ok, "Intercambio cancelado"} = GestorSalas.cancelar_intercambio(codigo, "luis")

    refute codigo in GestorSalas.salas_activas()
    refute codigo in :rpc.call(peer_node, GestorSalas, :salas_activas, [])
    refute Cluster.sala_intercambio_activa?("ana")
    refute Cluster.sala_intercambio_activa?("luis")
    assert Cluster.codigo_de_sala_intercambio("ana") == nil
    assert Cluster.codigo_de_sala_intercambio("luis") == nil
  end
end

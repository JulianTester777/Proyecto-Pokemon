defmodule PokemonBattle.Cluster do
  @moduledoc false

  @tabla_batallas :pokemon_battle_battle_nodes
  @tabla_intercambios :pokemon_battle_exchange_rooms
  @tabla_miembros_intercambio :pokemon_battle_exchange_members

  def nodos_disponibles do
    [Node.self() | Node.list()]
    |> Enum.uniq()
  end

  def nodo_para_crear_batalla(codigo) do
    case nodos_remotos() do
      [] -> Node.self()
      remotos -> Enum.at(remotos, :erlang.phash2(codigo, length(remotos)))
    end
  end

  def nodo_de_batalla(codigo) do
    ensure_table!(@tabla_batallas)

    case nodo_de_batalla_en_nodo(codigo) do
      nil -> buscar_nodo_remoto(:nodo_de_batalla_en_nodo, [codigo]) || Node.self()
      node -> node
    end
  end

  def nodo_de_batalla_en_nodo(codigo) do
    ensure_table!(@tabla_batallas)
    lookup_local(@tabla_batallas, codigo)
  end

  def registrar_batalla(codigo, node) do
    registrar_en_nodo(@tabla_batallas, codigo, node)
    broadcast(:registrar_batalla_en_nodo, [codigo, node])
    :ok
  end

  def registrar_batalla_en_nodo(codigo, node) do
    registrar_en_nodo(@tabla_batallas, codigo, node)
  end

  def codigos_batalla do
    ensure_table!(@tabla_batallas)

    ([codigos_en_nodo(@tabla_batallas)] ++ listar_remotos(:codigos_batalla_en_nodo, []))
    |> List.flatten()
    |> Enum.uniq()
  end

  def codigos_batalla_en_nodo do
    ensure_table!(@tabla_batallas)
    codigos_en_nodo(@tabla_batallas)
  end

  def liberar_batalla(codigo) do
    liberar_en_nodo(@tabla_batallas, codigo)
    broadcast(:liberar_batalla_en_nodo, [codigo])
    :ok
  end

  def liberar_batalla_en_nodo(codigo) do
    liberar_en_nodo(@tabla_batallas, codigo)
  end

  def batalla_activa?(codigo) do
    case nodo_de_batalla(codigo) do
      nil ->
        false

      node ->
        if node == Node.self() do
          batalla_activa_local?(codigo)
        else
          batalla_activa_remota?(node, codigo)
        end
    end
  end

  def nodo_de_sala_intercambio(codigo) do
    ensure_table!(@tabla_intercambios)

    case nodo_de_sala_intercambio_en_nodo(codigo) do
      nil -> buscar_nodo_remoto(:nodo_de_sala_intercambio_en_nodo, [codigo])
      node -> node
    end
  end

  def nodo_de_sala_intercambio_en_nodo(codigo) do
    ensure_table!(@tabla_intercambios)
    lookup_local(@tabla_intercambios, codigo)
  end

  def registrar_sala_intercambio(codigo, node) do
    registrar_en_nodo(@tabla_intercambios, codigo, node)
    broadcast(:registrar_sala_intercambio_en_nodo, [codigo, node])
    :ok
  end

  def registrar_sala_intercambio_en_nodo(codigo, node) do
    registrar_en_nodo(@tabla_intercambios, codigo, node)
  end

  def codigos_sala_intercambio do
    ensure_table!(@tabla_intercambios)

    ([codigos_en_nodo(@tabla_intercambios)] ++
       listar_remotos(:codigos_sala_intercambio_en_nodo, []))
    |> List.flatten()
    |> Enum.uniq()
  end

  def codigos_sala_intercambio_en_nodo do
    ensure_table!(@tabla_intercambios)
    codigos_en_nodo(@tabla_intercambios)
  end

  def liberar_sala_intercambio(codigo) do
    liberar_en_nodo(@tabla_intercambios, codigo)
    broadcast(:liberar_sala_intercambio_en_nodo, [codigo])
    :ok
  end

  def liberar_sala_intercambio_en_nodo(codigo) do
    liberar_en_nodo(@tabla_intercambios, codigo)
  end

  def sala_intercambio_activa?(usuario) do
    not is_nil(codigo_de_sala_intercambio(usuario))
  end

  def codigo_de_sala_intercambio(usuario) do
    ensure_table!(@tabla_miembros_intercambio)

    case codigo_de_sala_intercambio_en_nodo(usuario) do
      nil -> buscar_codigo_remoto(:codigo_de_sala_intercambio_en_nodo, [usuario])
      codigo -> codigo
    end
  end

  def codigo_de_sala_intercambio_en_nodo(usuario) do
    ensure_table!(@tabla_miembros_intercambio)
    lookup_local(@tabla_miembros_intercambio, usuario)
  end

  def registrar_miembro_intercambio(usuario, codigo) do
    ensure_table!(@tabla_miembros_intercambio)

    case :ets.lookup(@tabla_miembros_intercambio, usuario) do
      [] ->
        :ets.insert(@tabla_miembros_intercambio, {usuario, codigo})
        broadcast(:registrar_miembro_intercambio_en_nodo, [usuario, codigo])
        :ok

      [{^usuario, ^codigo}] ->
        :ok

      _ ->
        {:error, "Ya tienes una sala activa"}
    end
  end

  def registrar_miembro_intercambio_en_nodo(usuario, codigo) do
    ensure_table!(@tabla_miembros_intercambio)
    :ets.insert(@tabla_miembros_intercambio, {usuario, codigo})
    :ok
  end

  def liberar_miembro_intercambio(usuario) do
    ensure_table!(@tabla_miembros_intercambio)
    :ets.delete(@tabla_miembros_intercambio, usuario)
    broadcast(:liberar_miembro_intercambio_en_nodo, [usuario])
    :ok
  end

  def liberar_miembro_intercambio_en_nodo(usuario) do
    ensure_table!(@tabla_miembros_intercambio)
    :ets.delete(@tabla_miembros_intercambio, usuario)
    :ok
  end

  defp batalla_activa_local?(codigo) do
    try do
      case PokemonBattle.Batalla.estado(codigo) do
        %{ganador: nil} -> true
        _ -> false
      end
    catch
      :exit, _ -> false
    end
  end

  defp batalla_activa_remota?(node, codigo) do
    case :rpc.call(node, PokemonBattle.Batalla, :estado, [codigo]) do
      %{ganador: nil} -> true
      _ -> false
    end
  end

  defp lookup_local(tabla, key) do
    case :ets.lookup(tabla, key) do
      [{^key, value}] -> value
      _ -> nil
    end
  end

  defp codigos_en_nodo(tabla) do
    :ets.tab2list(tabla)
    |> Enum.map(&elem(&1, 0))
  end

  defp registrar_en_nodo(tabla, key, value) do
    ensure_table!(tabla)
    :ets.insert(tabla, {key, value})
    :ok
  end

  defp liberar_en_nodo(tabla, key) do
    ensure_table!(tabla)
    :ets.delete(tabla, key)
    :ok
  end

  defp broadcast(funcion, args) do
    Enum.each(nodos_remotos(), fn remoto ->
      _ = :rpc.call(remoto, __MODULE__, funcion, args)
    end)

    :ok
  end

  defp listar_remotos(funcion, args) do
    Enum.flat_map(nodos_remotos(), fn remoto ->
      case :rpc.call(remoto, __MODULE__, funcion, args) do
        list when is_list(list) -> list
        _ -> []
      end
    end)
  end

  defp buscar_nodo_remoto(funcion, args) do
    Enum.find_value(nodos_remotos(), fn remoto ->
      case :rpc.call(remoto, __MODULE__, funcion, args) do
        node when is_atom(node) -> node
        _ -> nil
      end
    end)
  end

  defp buscar_codigo_remoto(funcion, args) do
    Enum.find_value(nodos_remotos(), fn remoto ->
      case :rpc.call(remoto, __MODULE__, funcion, args) do
        codigo when is_binary(codigo) -> codigo
        _ -> nil
      end
    end)
  end

  defp nodos_remotos do
    Enum.reject(nodos_disponibles(), &(&1 == Node.self()))
  end

  defp ensure_table!(tabla) do
    case :ets.whereis(tabla) do
      :undefined ->
        _ = PokemonBattle.ClusterTables.ensure_tables()
        :ok

      _ ->
        :ok
    end
  end
end

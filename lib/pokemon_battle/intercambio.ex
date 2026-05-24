defmodule PokemonBattle.Intercambio do
  use GenServer

  alias PokemonBattle.{Cluster, GestorEntrenadores, GestorSalas}

  def start_link({codigo, creador}) do
    GenServer.start_link(__MODULE__, {codigo, creador}, name: via(codigo))
  end

  def unirse(codigo, usuario) do
    llamar_en_nodo(codigo, :unirse, [codigo, usuario], {:unirse, usuario})
  end

  def ofrecer(codigo, usuario, pokemon_id) do
    llamar_en_nodo(
      codigo,
      :ofrecer,
      [codigo, usuario, pokemon_id],
      {:ofrecer, usuario, pokemon_id}
    )
  end

  def confirmar(codigo, usuario) do
    llamar_en_nodo(codigo, :confirmar, [codigo, usuario], {:confirmar, usuario})
  end

  def cancelar(codigo, usuario) do
    llamar_en_nodo(codigo, :cancelar, [codigo, usuario], {:cancelar, usuario})
  end

  def estado_sala(codigo) do
    llamar_en_nodo(codigo, :estado_sala, [codigo], :estado_sala)
  end

  @impl true
  def init({codigo, creador}) do
    {:ok,
     %{
       codigo: codigo,
       jugador1: creador,
       jugador2: nil,
       ofertas: %{},
       confirmados: MapSet.new()
     }}
  end

  @impl true
  def handle_call({:unirse, usuario}, _from, estado) do
    cond do
      usuario == estado.jugador1 ->
        {:reply, {:error, "No puedes unirte a tu propia sala"}, estado}

      estado.jugador2 != nil ->
        {:reply, {:error, "La sala ya está llena"}, estado}

      GestorSalas.sala_activa?(usuario) ->
        {:reply, {:error, "Ya tienes una sala activa"}, estado}

      true ->
        nuevo_estado = %{estado | jugador2: usuario}

        case GestorSalas.registrar_sala(usuario, estado.codigo) do
          :ok ->
            msg = formatear_estado_sala(nuevo_estado, usuario)
            {:reply, {:ok, msg}, nuevo_estado}
          {:error, msg} ->
            {:reply, {:error, msg}, estado}
        end
    end
  end

  @impl true
  def handle_call({:ofrecer, usuario, pokemon_id}, _from, estado) do
    if usuario not in participantes(estado) do
      {:reply, {:error, "No estás en esta sala"}, estado}
    else
      with entrenador when not is_nil(entrenador) <- GestorEntrenadores.buscar_entrenador(usuario),
           true <- GestorEntrenadores.pokemon_pertenece?(entrenador, pokemon_id),
           false <- pokemon_en_equipo_activo?(entrenador, pokemon_id),
           pokemon when not is_nil(pokemon) <-
             GestorEntrenadores.buscar_pokemon(entrenador, pokemon_id) do
        nuevas_ofertas = Map.put(estado.ofertas, usuario, pokemon_id)
        nuevo_estado = %{estado | ofertas: nuevas_ofertas, confirmados: MapSet.new()}
        msg = formatear_estado_sala(nuevo_estado, usuario)
        {:reply, {:ok, msg}, nuevo_estado}
      else
        false -> {:reply, {:error, "El Pokémon no pertenece al entrenador"}, estado}
        true -> {:reply, {:error, "El Pokémon está cargado en un equipo activo"}, estado}
        nil -> {:reply, {:error, "El Pokémon no pertenece al entrenador"}, estado}
      end
    end
  end

  @impl true
  def handle_call({:confirmar, usuario}, _from, estado) do
    if usuario not in participantes(estado) do
      {:reply, {:error, "No estás en esta sala"}, estado}
    else
      cond do
        map_size(estado.ofertas) < 2 ->
          {:reply, {:error, "Ambos jugadores deben ofrecer un Pokémon antes de confirmar"}, estado}

        not Map.has_key?(estado.ofertas, usuario) ->
          {:reply, {:error, "Debes ofrecer un Pokémon antes de confirmar"}, estado}

        true ->
          nuevo_estado = %{estado | confirmados: MapSet.put(estado.confirmados, usuario)}

          if intercambio_listo?(nuevo_estado) do
            case ejecutar_intercambio(nuevo_estado) do
              {:ok, msg} ->
                {:stop, :normal, {:ok, msg}, nuevo_estado}

              {:error, reason} ->
                {:reply, {:error, reason}, estado}
            end
          else
            msg = formatear_estado_sala(nuevo_estado, usuario)
            {:reply, {:ok, msg}, nuevo_estado}
          end
      end
    end
  end

  @impl true
  def handle_call({:cancelar, usuario}, _from, estado) do
    if usuario not in participantes(estado) do
      {:reply, {:error, "No estás en esta sala"}, estado}
    else
      {:stop, :normal, {:ok, "Intercambio cancelado"}, estado}
    end
  end

  @impl true
  def handle_call(:estado_sala, _from, estado) do
    {:reply, estado, estado}
  end

  @impl true
  def terminate(_reason, estado) do
    Enum.each(participantes(estado), &GestorSalas.liberar_sala/1)
    Cluster.liberar_sala_intercambio(estado.codigo)
    :ok
  end

  defp formatear_estado_sala(estado, usuario_actual) do
    j1 = estado.jugador1
    j2 = estado.jugador2

    linea_j1 = formatear_linea_jugador(j1, estado, usuario_actual)
    linea_j2 = formatear_linea_jugador(j2, estado, usuario_actual)

    confirmados = estado.confirmados

    estado_confirmacion =
      cond do
        map_size(estado.ofertas) < 2 ->
          "Esperando ofertas..."

        MapSet.size(confirmados) == 0 ->
          "Ambos han ofrecido. Confirma con: confirmar_intercambio"

        MapSet.size(confirmados) == 1 ->
          "Un jugador confirmó. Esperando al otro..."

        true ->
          "Intercambio listo."
      end

    """
    \n[Sala #{estado.codigo}]
    #{linea_j1}
    #{linea_j2}
    #{estado_confirmacion}
    """
  end

  defp formatear_linea_jugador(nil, _estado, _usuario_actual) do
    "  ? → (esperando jugador)"
  end

  defp formatear_linea_jugador(jugador, estado, usuario_actual) do
    oferta = Map.get(estado.ofertas, jugador)
    confirmado = MapSet.member?(estado.confirmados, jugador)

    oferta_str =
      if oferta do
        entrenador = GestorEntrenadores.buscar_entrenador(jugador)
        pokemon = if entrenador, do: GestorEntrenadores.buscar_pokemon(entrenador, oferta), else: nil

        if pokemon do
          tipos = Enum.map_join(List.wrap(pokemon.tipos), "/", &String.capitalize/1)
          "[##{pokemon.id}] #{String.capitalize(pokemon.especie)} (#{tipos}, #{pokemon.rareza})"
        else
          "[##{oferta}]"
        end
      else
        "(sin oferta)"
      end

    confirmacion_str = if confirmado, do: " ✓ confirmado", else: ""
    tuyo = if jugador == usuario_actual, do: " (tú)", else: ""

    "  #{jugador}#{tuyo} → #{oferta_str}#{confirmacion_str}"
  end

  defp participantes(estado) do
    [estado.jugador1, estado.jugador2] |> Enum.reject(&is_nil/1)
  end

  defp intercambio_listo?(estado) do
    estado.jugador1 != nil and
      estado.jugador2 != nil and
      map_size(estado.ofertas) == 2 and
      MapSet.size(estado.confirmados) == 2
  end

  defp ejecutar_intercambio(estado) do
    j1 = estado.jugador1
    j2 = estado.jugador2
    p1 = estado.ofertas[j1]
    p2 = estado.ofertas[j2]

    case GestorEntrenadores.intercambiar(j1, p1, j2, p2) do
      {:ok, _} -> {:ok, "[Intercambio completado] #{j1} ↔ #{j2}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp pokemon_en_equipo_activo?(entrenador, pokemon_id) do
    case entrenador.equipo_actual do
      nil ->
        false

      nombre ->
        case Enum.find(entrenador.equipos, &(&1["nombre"] == nombre)) do
          nil -> false
          equipo -> Enum.member?(List.wrap(equipo["pokemon_ids"]), pokemon_id)
        end
    end
  end

  defp llamar_en_nodo(codigo, funcion, args, mensaje_local) do
    case Cluster.nodo_de_sala_intercambio(codigo) do
      nil ->
        {:error, "No existe una sala con código #{codigo}"}

      node ->
        if node == Node.self() do
          call_local(codigo, mensaje_local)
        else
          case :rpc.call(node, __MODULE__, funcion, args) do
            {:badrpc, _} -> {:error, "No existe una sala con código #{codigo}"}
            other -> other
          end
        end
    end
  end

  defp call_local(codigo, mensaje) do
    try do
      GenServer.call(via(codigo), mensaje)
    catch
      :exit, {:noproc, _} -> {:error, "No existe una sala con código #{codigo}"}
    end
  end

  defp via(codigo) do
    {:via, Registry, {PokemonBattle.Registry, codigo}}
  end
end

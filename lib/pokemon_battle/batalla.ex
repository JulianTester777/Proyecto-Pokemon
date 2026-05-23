defmodule PokemonBattle.Batalla do
  use GenServer

  alias PokemonBattle.{GestorEntrenadores, MotorCombate, UI}

  def start_link({id, jugador1}), do: start_link({id, jugador1, []})

  def start_link({id, jugador1, opts}) do
    try do
      GenServer.start_link(__MODULE__, {id, jugador1, opts}, name: via(id))
    catch
      :exit, reason -> {:error, reason}
    end
  end

  def unirse(id, jugador2), do: llamar_en_nodo(id, :unirse, [id, jugador2], {:unirse, jugador2})

  def atacar(id, nombre, movimiento),
    do:
      llamar_en_nodo(
        id,
        :atacar,
        [id, nombre, movimiento],
        {:accion, nombre, {:atacar, movimiento}}
      )

  def cambiar(id, nombre, pokemon_id),
    do:
      llamar_en_nodo(
        id,
        :cambiar,
        [id, nombre, pokemon_id],
        {:accion, nombre, {:cambiar, pokemon_id}}
      )

  def pasar(id, nombre), do: llamar_en_nodo(id, :pasar, [id, nombre], {:accion, nombre, :pasar})
  def rendirse(id, nombre), do: llamar_en_nodo(id, :rendirse, [id, nombre], {:rendirse, nombre})
  def estado(id), do: llamar_en_nodo(id, :estado, [id], :estado)

  @impl true
  def init({id, jugador1, opts}) do
    case seleccionar_pokemon_usable(jugador1) do
      {:ok, activo} ->
        equipo = List.wrap(Map.get(jugador1, :coleccion, []))
        tiempo_turno = normalizar_tiempo(Keyword.get(opts, :tiempo_turno, 20_000))

        jugador1_estado = restaurar_salud(%{
          entrenador: jugador1,
          activo: activo,
          equipo: equipo,
          accion: nil
        })

        estado = %{
          id: id,
          turno: 1,
          tiempo_turno: tiempo_turno,
          timer_ref: nil,
          inicio: DateTime.utc_now(),
          jugadores: %{
            jugador1.nombre => jugador1_estado
          },
          ganador: nil
        }

        IO.puts("⚔️  Batalla #{id} creada. Esperando segundo jugador...")
        {:ok, estado}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:unirse, jugador2}, _from, estado) do
    cond do
      map_size(estado.jugadores) >= 2 ->
        {:reply, {:error, "Sala llena"}, estado}

      Map.has_key?(estado.jugadores, jugador2.nombre) ->
        {:reply, {:error, "No puedes unirte a tu propia batalla"}, estado}

      true ->
        case seleccionar_pokemon_usable(jugador2) do
          {:ok, activo} ->
            equipo = List.wrap(Map.get(jugador2, :coleccion, []))

            nuevo = restaurar_salud(%{
              entrenador: jugador2,
              activo: activo,
              equipo: equipo,
              accion: nil
            })

            estado2 = put_in(estado, [:jugadores, jugador2.nombre], nuevo)
            estado3 = iniciar_turno(estado2)
            {:reply, :ok, estado3}

          {:error, reason} ->
            {:reply, {:error, reason}, estado}
        end
    end
  end

  @impl true
  def handle_call({:accion, nombre, accion}, _from, estado) do
    if ganador_definido?(estado) do
      {:reply, {:error, "La batalla ya terminó"}, estado}
    else
      cond do
        not Map.has_key?(estado.jugadores, nombre) ->
          {:reply, {:error, "No participas en esta batalla"}, estado}

        true ->
          case validar_accion(estado, nombre, accion) do
            :ok ->
              estado2 = put_in(estado, [:jugadores, nombre, :accion], accion)

              if todos_listos?(estado2) do
                estado3 = resolver_turno(estado2)
                {:reply, :ok, estado3}
              else
                {:reply, :esperando, estado2}
              end

            {:error, reason} ->
              {:reply, {:error, reason}, estado}
          end
      end
    end
  end

  @impl true
  def handle_call({:rendirse, nombre}, _from, estado) do
    case rival_de(estado, nombre) do
      nil ->
        {:reply, {:error, "No participas en esta batalla"}, estado}

      rival ->
        estado2 = finalizar_con_ganador(estado, rival)
        {:reply, :ok, estado2}
    end
  end

  @impl true
  def handle_call(:estado, _from, estado) do
    {:reply, estado, estado}
  end

  @impl true
  def handle_info({:turn_timeout, turno}, estado) do
    if estado.turno == turno and not ganador_definido?(estado) do
      estado2 =
        estado
        |> completar_acciones_con_pasar()
        |> resolver_turno()

      {:noreply, estado2}
    else
      {:noreply, estado}
    end
  end

  @impl true
  def handle_info(:timeout_desconexion, estado) do
    if not ganador_definido?(estado) and map_size(estado.jugadores) == 2 do
      [n1, n2] = Map.keys(estado.jugadores)
      ganador = if equipo_tiene_vivos?(estado.jugadores[n1].equipo), do: n1, else: n2
      IO.puts("⏱️  Tiempo de espera agotado. #{ganador} gana por abandono.")
      estado2 = finalizar_con_ganador(estado, ganador)
      {:noreply, estado2}
    else
      {:noreply, estado}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, estado) do
    if not ganador_definido?(estado) and map_size(estado.jugadores) == 2 do
      IO.puts("⚠️  Un jugador se desconectó. Esperando 15 segundos antes de dar la victoria al rival...")
      ref = Process.send_after(self(), :timeout_desconexion, 15_000)
      {:noreply, Map.put(estado, :disconnect_timer, ref)}
    else
      {:noreply, estado}
    end
  end


  defp iniciar_turno(estado) do
    estado = preparar_activos(estado)
    cancel_timer(estado.timer_ref)
    mostrar_turno(estado)
    ref = Process.send_after(self(), {:turn_timeout, estado.turno}, estado.tiempo_turno)
    %{estado | timer_ref: ref}
  end

  defp resolver_turno(estado) do
    cancel_timer(estado.timer_ref)
    [n1, n2] = Map.keys(estado.jugadores)
    j1 = estado.jugadores[n1]
    j2 = estado.jugadores[n2]

    orden = resolver_orden({n1, j1}, {n2, j2})

    estado2 =
      Enum.reduce_while(orden, estado, fn {nombre, _j}, acc ->
        rival = rival_de(acc, nombre)
        accion = acc.jugadores[nombre].accion

        cond do
          ganador_definido?(acc) -> {:halt, acc}
          is_nil(rival) -> {:halt, acc}
          not vivo?(acc.jugadores[nombre].activo) -> {:cont, acc}
          not vivo?(acc.jugadores[rival].activo) and accion != {:cambiar, nil} -> {:cont, acc}
          true -> {:cont, ejecutar_accion(acc, nombre, rival, accion)}
        end
      end)

    estado3 =
      estado2
      |> limpiar_acciones()
      |> notificar_debilitados()
      |> preparar_activos()
      |> verificar_fin()

    case estado3 do
      %{ganador: nil} ->
        estado3
        |> Map.update!(:turno, &(&1 + 1))
        |> iniciar_turno()

      _ ->
        estado3
    end
  end

  defp ejecutar_accion(estado, atacante, defensor, accion) do
    case accion do
      :pasar ->
        estado

      {:cambiar, pokemon_id} ->
        cambiar_activo(estado, atacante, pokemon_id)

      {:atacar, nombre_mov} ->
        j_atac = estado.jugadores[atacante]
        j_def = estado.jugadores[defensor]

        mov = Enum.find(List.wrap(j_atac.activo.movimientos), &(&1.nombre == nombre_mov))

        if mov do
          danio =
            MotorCombate.calcular_daño(
              j_atac.activo,
              j_def.activo,
              mov,
              Map.get(j_atac.activo, :tipos, []),
              Map.get(j_def.activo, :tipos, [])
            )

          nueva_salud = max(0, j_def.activo.salud_actual - danio)


          UI.mostrar_ataque(atacante, nombre_mov, danio, defensor, nueva_salud)

          activo_actualizado = %{j_def.activo | salud_actual: nueva_salud}

          estado
          |> put_in([:jugadores, defensor, :activo], activo_actualizado)
          |> actualizar_equipo_con_activo(defensor, activo_actualizado)
        else
          estado
        end

      _ ->
        estado
    end
  end

  defp cambiar_activo(estado, nombre, pokemon_id) do
    jugador = estado.jugadores[nombre]

    case Enum.find(jugador.equipo, &(&1.id == pokemon_id and vivo?(&1))) do
      nil ->
        estado

      pokemon ->
        IO.puts("🔁 #{nombre} cambia a ##{pokemon.id} #{String.capitalize(pokemon.especie)}")
        put_in(estado, [:jugadores, nombre, :activo], pokemon)
    end
  end

  defp actualizar_equipo_con_activo(estado, nombre, activo) do
    actualizar = fn pokemon -> if pokemon.id == activo.id, do: activo, else: pokemon end

    update_in(estado, [:jugadores, nombre, :equipo], fn equipo -> Enum.map(equipo, actualizar) end)
  end

  defp completar_acciones_con_pasar(estado) do
    Enum.reduce(estado.jugadores, estado, fn {nombre, _}, acc ->
      if is_nil(acc.jugadores[nombre].accion) do
        put_in(acc, [:jugadores, nombre, :accion], :pasar)
      else
        acc
      end
    end)
  end

  defp restaurar_salud(jugador) do
    equipo = Enum.map(jugador.equipo, fn p -> %{p | salud_actual: p.salud_maxima} end)
    activo = %{jugador.activo | salud_actual: jugador.activo.salud_maxima}
    %{jugador | equipo: equipo, activo: activo}
  end

  defp preparar_activos(estado) do
    Enum.reduce(estado.jugadores, estado, fn {nombre, jugador}, acc ->
      case jugador.activo do
        %{salud_actual: s} when s > 0 ->
          acc

        _ ->
          case siguiente_pokemon_vivo(jugador.equipo) do
            nil -> acc
            pokemon -> put_in(acc, [:jugadores, nombre, :activo], pokemon)
          end
      end
    end)
  end

  defp notificar_debilitados(estado) do
    Enum.each(estado.jugadores, fn {nombre, jugador} ->
      if not vivo?(jugador.activo) do
        siguiente = siguiente_pokemon_vivo(jugador.equipo)
        if siguiente do
          IO.puts("\n⚠️  #{nombre}: tu Pokémon fue debilitado. Se selecciona automáticamente #{String.capitalize(siguiente.especie)}.")
        end
      end
    end)
    estado
  end

  defp siguiente_pokemon_vivo(equipo) do
    Enum.find(equipo, &vivo?/1)
  end

  defp verificar_fin(estado) do
    [n1, n2] = Map.keys(estado.jugadores)

    cond do
      not equipo_tiene_vivos?(estado.jugadores[n1].equipo) -> finalizar_con_ganador(estado, n2)
      not equipo_tiene_vivos?(estado.jugadores[n2].equipo) -> finalizar_con_ganador(estado, n1)
      true -> estado
    end
  end

  defp finalizar_con_ganador(estado, ganador) do
    [n1, n2] = Map.keys(estado.jugadores)
    perdedor = if ganador == n1, do: n2, else: n1
    estado = %{estado | ganador: ganador}
    finalizar_batalla(estado, perdedor)
  end

  defp finalizar_batalla(estado, perdedor) do
    ganador = estado.ganador
    UI.mostrar_ganador(ganador)
    IO.puts("💰 #{ganador} +100 monedas | #{perdedor} +30 monedas")

    e_gan = estado.jugadores[ganador].entrenador
    e_per = estado.jugadores[perdedor].entrenador

    GestorEntrenadores.guardar_entrenador(%{
      e_gan
      | monedas: e_gan.monedas + 100,
        monedas_acumuladas: e_gan.monedas_acumuladas + 100,
        victorias: e_gan.victorias + 1
    })

    GestorEntrenadores.guardar_entrenador(%{
      e_per
      | monedas: e_per.monedas + 30,
        monedas_acumuladas: e_per.monedas_acumuladas + 30
    })

    duracion = DateTime.diff(DateTime.utc_now(), estado.inicio)

    entrada =
      "#{DateTime.utc_now()} | #{Map.keys(estado.jugadores) |> Enum.join(" vs ")} | " <>
        "Ganador: #{ganador} | Nodo: #{Node.self()} | " <>
        "Turnos: #{estado.turno} | Duración: #{duracion}s\n"

    _ = PokemonBattle.Persistencia.append_line("data/battles.log", entrada)
    PokemonBattle.Cluster.liberar_batalla(estado.id)
    %{estado | timer_ref: nil}
  end

  defp resolver_orden({n1, j1}, {n2, j2}) do
    cond do
      j1.activo.velocidad > j2.activo.velocidad -> [{n1, j1}, {n2, j2}]
      j2.activo.velocidad > j1.activo.velocidad -> [{n2, j2}, {n1, j1}]
      true -> Enum.shuffle([{n1, j1}, {n2, j2}])
    end
  end

  defp validar_accion(estado, nombre, {:atacar, mov}) do
    movs = List.wrap(estado.jugadores[nombre].activo.movimientos)

    if Enum.any?(movs, &(&1.nombre == mov)) do
      :ok
    else
      {:error, "Movimiento #{mov} no válido"}
    end
  end

  defp validar_accion(estado, nombre, {:cambiar, pokemon_id}) do
    jugador = estado.jugadores[nombre]

    cond do
      is_nil(Enum.find(jugador.equipo, &(&1.id == pokemon_id))) ->
        {:error, "El Pokémon no está en tu equipo"}

      not vivo?(Enum.find(jugador.equipo, &(&1.id == pokemon_id))) ->
        {:error, "El Pokémon está debilitado"}

      true ->
        :ok
    end
  end

  defp validar_accion(_estado, _nombre, :pasar), do: :ok
  defp validar_accion(_estado, _nombre, _), do: :ok

  defp todos_listos?(estado) do
    estado.jugadores
    |> Map.values()
    |> Enum.all?(&(&1.accion != nil))
  end

  defp limpiar_acciones(estado) do
    Enum.reduce(Map.keys(estado.jugadores), estado, fn nombre, acc ->
      put_in(acc, [:jugadores, nombre, :accion], nil)
    end)
  end

  defp vivo?(%{salud_actual: salud}), do: salud > 0
  defp vivo?(_), do: false

  defp equipo_tiene_vivos?(equipo), do: Enum.any?(equipo, &vivo?/1)

  defp seleccionar_pokemon_usable(entrenador) do
    case Enum.find(List.wrap(Map.get(entrenador, :coleccion, [])), &vivo?/1) do
      nil ->
        {:error, "El entrenador #{entrenador.nombre} no tiene un Pokémon usable para la batalla"}

      pokemon ->
        {:ok, pokemon}
    end
  end

  defp rival_de(estado, nombre) do
    estado.jugadores
    |> Map.keys()
    |> Enum.reject(&(&1 == nombre))
    |> List.first()
  end

  defp ganador_definido?(estado), do: not is_nil(estado.ganador)

  defp normalizar_tiempo(tiempo) when is_integer(tiempo) and tiempo < 1000, do: tiempo * 1000
  defp normalizar_tiempo(tiempo) when is_integer(tiempo), do: tiempo
  defp normalizar_tiempo(_), do: 20_000

  defp mostrar_turno(estado) do
    UI.separador()
    IO.puts(UI.negrita(UI.amarillo("══════════ Turno #{estado.turno} ══════════")))

    [n1, n2] = Map.keys(estado.jugadores)

    Enum.each([{n1, n2}, {n2, n1}], fn {nombre, nombre_rival} ->
      yo = estado.jugadores[nombre]
      rival = estado.jugadores[nombre_rival]
      p_yo = yo.activo
      p_rival = rival.activo

      equipo_propio =
        yo.equipo
        |> Enum.map_join(" | ", fn p ->
          cond do
            p.id == p_yo.id -> "[##{p.id}] #{String.capitalize(p.especie)} (activo)"
            vivo?(p) -> "[##{p.id}] #{String.capitalize(p.especie)} (vivo)"
            true -> "[##{p.id}] #{String.capitalize(p.especie)} (debilitado)"
          end
        end)

      equipo_rival =
        rival.equipo
        |> Enum.map_join(" | ", fn p ->
          cond do
            p.id == p_rival.id -> "#{String.capitalize(p.especie)} (activo)"
            vivo?(p) -> "#{String.capitalize(p.especie)} (vivo)"
            true -> "#{String.capitalize(p.especie)} (debilitado)"
          end
        end)

      movs =
        List.wrap(p_yo.movimientos)
        |> Enum.map_join(", ", fn m ->
          "#{m.nombre}(#{m.tipo}, poder #{m.poder_base})"
        end)

      IO.puts("\n--- #{nombre} ---")
      IO.puts("Rival: #{nombre_rival} | #{String.capitalize(p_rival.especie)} | Salud: #{UI.barra_salud(p_rival.salud_actual, p_rival.salud_maxima)}")
      IO.puts("Equipo rival: #{equipo_rival}")
      IO.puts("Tu Pokémon: [##{p_yo.id}] #{String.capitalize(p_yo.especie)} | Salud: #{UI.barra_salud(p_yo.salud_actual, p_yo.salud_maxima)} | Vel: #{p_yo.velocidad}")
      IO.puts("Tu equipo: #{equipo_propio}")
      IO.puts("Movimientos: #{movs}")
    end)

    UI.separador()
  end


  defp cancel_timer(nil), do: :ok
  defp cancel_timer(ref), do: Process.cancel_timer(ref)

  defp llamar_en_nodo(id, funcion, args, mensaje_local) do
    node = PokemonBattle.Cluster.nodo_de_batalla(id)

    if node == Node.self() do
      GenServer.call(via(id), mensaje_local)
    else
      :rpc.call(node, __MODULE__, funcion, args)
    end
  end

  @impl true
  def terminate(_reason, estado) do
    if Map.has_key?(estado, :id) do
      PokemonBattle.Cluster.liberar_batalla(estado.id)
    end

    :ok
  end

  defp via(id) do
    {:via, Registry, {PokemonBattle.Registry, id}}
  end
end

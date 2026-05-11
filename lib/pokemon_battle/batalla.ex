defmodule PokemonBattle.Batalla do
  use GenServer

  alias PokemonBattle.{MotorCombate, GestorEntrenadores}

  # --- API pública ---

  def start_link({id, jugador1}) do
    GenServer.start_link(__MODULE__, {id, jugador1}, name: via(id))
  end

  def unirse(id, jugador2) do
    GenServer.call(via(id), {:unirse, jugador2})
  end

  def atacar(id, nombre, movimiento) do
    GenServer.call(via(id), {:atacar, nombre, movimiento})
  end

  def rendirse(id, nombre) do
    GenServer.call(via(id), {:rendirse, nombre})
  end

  def estado(id) do
    GenServer.call(via(id), :estado)
  end

  # --- Init ---

  @impl true
  def init({id, jugador1}) do
    estado = %{
      id:        id,
      turno:     1,
      inicio:    DateTime.utc_now(),
      jugadores: %{
        jugador1.nombre => %{
          entrenador: jugador1,
          activo:     hd(jugador1.coleccion),
          equipo:     jugador1.coleccion,
          accion:     nil
        }
      },
      ganador: nil
    }
    IO.puts("⚔️  Batalla #{id} creada. Esperando segundo jugador...")
    {:ok, estado}
  end

  # --- Unirse ---

  @impl true
  def handle_call({:unirse, jugador2}, _from, estado) do
    if map_size(estado.jugadores) >= 2 do
      {:reply, {:error, "Sala llena"}, estado}
    else
      nuevo = %{
        entrenador: jugador2,
        activo:     hd(jugador2.coleccion),
        equipo:     jugador2.coleccion,
        accion:     nil
      }
      estado2 = put_in(estado, [:jugadores, jugador2.nombre], nuevo)
      IO.puts("✅ #{jugador2.nombre} se unió. ¡Batalla iniciada!")
      mostrar_turno(estado2)
      {:reply, :ok, estado2}
    end
  end

  # --- Atacar ---

  @impl true
  def handle_call({:atacar, nombre, movimiento}, _from, estado) do
    estado2 = put_in(estado, [:jugadores, nombre, :accion], {:atacar, movimiento})
    acciones = Enum.map(estado2.jugadores, fn {_, j} -> j.accion end)

    if Enum.all?(acciones, &(&1 != nil)) do
      estado3 = resolver_turno(estado2)
      {:reply, :ok, estado3}
    else
      IO.puts("⏳ Esperando al rival...")
      {:reply, :esperando, estado2}
    end
  end

  # --- Rendirse ---

  @impl true
  def handle_call({:rendirse, nombre}, _from, estado) do
    [rival] = Map.keys(estado.jugadores) |> Enum.reject(&(&1 == nombre))
    IO.puts("🏳️  #{nombre} se rinde.")
    estado2 = Map.put(estado, :ganador, rival)
    finalizar_batalla(estado2)
    {:reply, :ok, estado2}
  end

  # --- Estado ---

  @impl true
  def handle_call(:estado, _from, estado) do
    {:reply, estado, estado}
  end

  # --- Resolver turno ---

  defp resolver_turno(estado) do
    [n1, n2] = Map.keys(estado.jugadores)
    j1 = estado.jugadores[n1]
    j2 = estado.jugadores[n2]

    {primero, segundo} =
      if j1.activo.velocidad >= j2.activo.velocidad,
        do: {n1, n2}, else: {n2, n1}

    estado2 = ejecutar_accion(estado, primero, segundo)

    estado3 =
      if vivo?(estado2.jugadores[segundo].activo) do
        ejecutar_accion(estado2, segundo, primero)
      else
        estado2
      end

    estado4 = estado3
      |> put_in([:jugadores, n1, :accion], nil)
      |> put_in([:jugadores, n2, :accion], nil)
      |> Map.update!(:turno, &(&1 + 1))

    verificar_fin(estado4)
  end

  defp ejecutar_accion(estado, atacante, defensor) do
    j_atac = estado.jugadores[atacante]
    j_def  = estado.jugadores[defensor]

    case j_atac.accion do
      {:atacar, nombre_mov} ->
        mov = Enum.find(j_atac.activo.movimientos, fn m ->
          m.nombre == nombre_mov
        end)

        if mov do
          # Usamos la firma del repo: calcular_daño(atacante, defensor, mov, tipos_atac, tipos_def)
          danio = MotorCombate.calcular_daño(
            j_atac.activo,
            j_def.activo,
            mov,
            j_atac.activo.tipos,
            j_def.activo.tipos
          )

          nueva_salud = max(0, j_def.activo.salud_actual - danio)
          IO.puts("💥 #{atacante} usa #{nombre_mov} → #{danio} daño a #{defensor} (Salud: #{nueva_salud})")

          activo = %{j_def.activo | salud_actual: nueva_salud}
          put_in(estado, [:jugadores, defensor, :activo], activo)
        else
          IO.puts("❌ Movimiento #{nombre_mov} no válido")
          estado
        end

      _ -> estado
    end
  end

  defp vivo?(pokemon), do: pokemon.salud_actual > 0

  defp verificar_fin(estado) do
    [n1, n2] = Map.keys(estado.jugadores)
    cond do
      not vivo?(estado.jugadores[n1].activo) ->
        estado2 = Map.put(estado, :ganador, n2)
        finalizar_batalla(estado2)
        estado2
      not vivo?(estado.jugadores[n2].activo) ->
        estado2 = Map.put(estado, :ganador, n1)
        finalizar_batalla(estado2)
        estado2
      true ->
        mostrar_turno(estado)
        estado
    end
  end

  # --- Finalizar: monedas + log ---

  defp finalizar_batalla(estado) do
    ganador  = estado.ganador
    [n1, n2] = Map.keys(estado.jugadores)
    perdedor = if ganador == n1, do: n2, else: n1

    IO.puts("\n🏆 ¡#{ganador} gana la batalla!")
    IO.puts("💰 #{ganador} +100 monedas | #{perdedor} +30 monedas")

    e_gan = estado.jugadores[ganador].entrenador
    e_per = estado.jugadores[perdedor].entrenador

    GestorEntrenadores.guardar_entrenador(%{e_gan |
      monedas:            e_gan.monedas + 100,
      monedas_acumuladas: e_gan.monedas_acumuladas + 100,
      victorias:          e_gan.victorias + 1
    })

    GestorEntrenadores.guardar_entrenador(%{e_per |
      monedas:            e_per.monedas + 30,
      monedas_acumuladas: e_per.monedas_acumuladas + 30
    })

    duracion = DateTime.diff(DateTime.utc_now(), estado.inicio)
    entrada  = "#{DateTime.utc_now()} | #{n1} vs #{n2} | " <>
               "Ganador: #{ganador} | Nodo: #{Node.self()} | " <>
               "Turnos: #{estado.turno} | Duración: #{duracion}s\n"
    File.write("data/battles.log", entrada, [:append])
  end

  defp mostrar_turno(estado) do
    IO.puts("\n═══ Turno #{estado.turno} ═══")
    Enum.each(estado.jugadores, fn {nombre, j} ->
      p    = j.activo
      movs = Enum.map_join(p.movimientos, ", ", fn m ->
        "#{m.nombre}(#{m.poder_base})"
      end)
      IO.puts("#{nombre} → #{p.especie} | Salud: #{p.salud_actual}/#{p.salud_maxima} | #{movs}")
    end)
  end

  defp via(id) do
    {:via, Registry, {PokemonBattle.Registry, id}}
  end

end

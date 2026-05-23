defmodule PokemonBattle.Servidor do
  alias PokemonBattle.{Batalla, GestorEntrenadores, GestorSalas, Persistencia, SupervisorBatallas}

  def iniciar do
    movs_base = Persistencia.cargar_datos("data/moves.json")
    tienda = Persistencia.cargar_datos("data/tienda.json")
    especies = Persistencia.cargar_especies("data/pokemon.json")

    IO.puts("==================================")
    IO.puts("   BIENVENIDO A POKÉMON BATTLE    ")
    IO.puts("==================================")

    bucle_login(especies, movs_base, tienda)
  end

  defp bucle_login(especies, movs, tienda) do
    comando = IO.gets("\n> ") |> String.trim()

    case String.split(comando) do
      ["iniciar", nombre, clave] ->
        case GestorEntrenadores.iniciar_sesion(nombre, clave) do
          %{} = entrenador -> bucle_principal(entrenador, especies, movs, tienda, nil, nil, true)
          {:error, msg} -> IO.puts(msg); bucle_login(especies, movs, tienda)
        end

      ["iniciar", nombre] ->
        case GestorEntrenadores.iniciar_sesion(nombre, "") do
          %{} = entrenador -> bucle_principal(entrenador, especies, movs, tienda, nil, nil, true)
          {:error, msg} -> IO.puts(msg); bucle_login(especies, movs, tienda)
        end

      ["salir"] ->
        IO.puts("¡Hasta luego!")

      _ ->
        IO.puts("Usa: iniciar <usuario> <clave>")
        bucle_login(especies, movs, tienda)
    end
  end

  defp bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio, mostrar_menu \\ false) do
    if mostrar_menu do
      IO.puts("\nComandos disponibles:")
      IO.puts("  perfil | inventario | clasificacion | tienda")
      IO.puts("  comprar_sobre <tipo> | abrir_sobre <id|ultimo>")
      IO.puts("  crear_equipo <nombre> <id1[,id2,id3]> | listar_equipos")
      IO.puts("  usar_equipo <nombre> | agregar_pokemon_equipo <nombre> <id> | quitar_pokemon_equipo <nombre> <id>")
      IO.puts("  crear_batalla [tiempo_turno=20] | listar_salas")
      IO.puts("  unirse_batalla <codigo> | iniciar_batalla <codigo>")
      IO.puts("  atacar <movimiento> | cambiar <id_pokemon> | pasar | rendirse")
      IO.puts("  crear_sala_intercambio | unirse_sala_intercambio <codigo>")
      IO.puts("  ofrecer_pokemon <id> | confirmar_intercambio | cancelar_intercambio")
      IO.puts("  ayuda | salir")
    end

    comando = IO.gets("\n> ") |> String.trim()

    case String.split(comando) do
      ["ayuda"] ->
        bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio, true)

      ["perfil"] ->
        GestorEntrenadores.perfil(entrenador)
        bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)

      ["inventario"] ->
        GestorEntrenadores.inventario(entrenador, especies)
        bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)

      ["clasificacion"] ->
        entrenadores = GestorEntrenadores.cargar_todos()
        clasificacion = GestorEntrenadores.clasificacion(entrenadores)

        IO.puts("\n=== Clasificación Global ===")
        IO.puts("#  | Entrenador | Victorias | Monedas acumuladas")
        IO.puts(String.duplicate("-", 50))

        Enum.each(clasificacion, fn {i, e} ->
          IO.puts("#{i}  | #{e.nombre} | #{e.victorias} | #{e.monedas_acumuladas}")
        end)

        bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)

      ["tienda"] ->
        mostrar_tienda(tienda)
        bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)

      ["comprar_sobre", tipo] ->
        entrenador_actualizado = comprar_sobre(entrenador, tipo, tienda)
        bucle_principal(entrenador_actualizado, especies, movs, tienda, batalla_actual, sala_intercambio)

      ["abrir_sobre"] ->
        entrenador_actualizado = abrir_sobre(entrenador, "ultimo", especies, movs, tienda)
        bucle_principal(entrenador_actualizado, especies, movs, tienda, batalla_actual, sala_intercambio)

      ["abrir_sobre", selector] ->
        entrenador_actualizado = abrir_sobre(entrenador, selector, especies, movs, tienda)
        bucle_principal(entrenador_actualizado, especies, movs, tienda, batalla_actual, sala_intercambio)

      ["crear_equipo", nombre, ids] ->
        entrenador_actualizado =
          case GestorEntrenadores.crear_equipo(entrenador, nombre, ids) do
            {:ok, updated} -> IO.puts("Equipo #{nombre} creado"); updated
            {:error, msg} -> IO.puts(msg); entrenador
          end

        bucle_principal(refrescar_entrenador(entrenador_actualizado), especies, movs, tienda, batalla_actual, sala_intercambio)

      ["listar_equipos"] ->
        IO.puts(GestorEntrenadores.listar_equipos(entrenador))
        bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)

      ["usar_equipo", nombre] ->
        case GestorEntrenadores.usar_equipo(entrenador, nombre) do
          {:ok, updated} ->
            IO.puts("Equipo #{nombre} seleccionado")
            bucle_principal(updated, especies, movs, tienda, batalla_actual, sala_intercambio)

          {:error, msg} ->
            IO.puts(msg)
            bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)
        end

      ["agregar_pokemon_equipo", nombre, id] ->
        case GestorEntrenadores.agregar_pokemon_equipo(entrenador, nombre, String.to_integer(id)) do
          {:ok, updated} ->
            IO.puts("Pokémon agregado al equipo")
            bucle_principal(updated, especies, movs, tienda, batalla_actual, sala_intercambio)

          {:error, msg} ->
            IO.puts(msg)
            bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)
        end

      ["quitar_pokemon_equipo", nombre, id] ->
        case GestorEntrenadores.quitar_pokemon_equipo(entrenador, nombre, String.to_integer(id)) do
          {:ok, updated} ->
            IO.puts("Pokémon quitado del equipo")
            bucle_principal(updated, especies, movs, tienda, batalla_actual, sala_intercambio)

          {:error, msg} ->
            IO.puts(msg)
            bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)
        end

      ["crear_batalla"] ->
        crear_sala_batalla(entrenador, nil, especies, movs, tienda, batalla_actual, sala_intercambio)

      ["crear_batalla", "tiempo_turno=" <> tiempo] ->
        crear_sala_batalla(entrenador, tiempo, especies, movs, tienda, batalla_actual, sala_intercambio)

      ["crear_sala"] ->
        crear_sala_batalla(entrenador, nil, especies, movs, tienda, batalla_actual, sala_intercambio)

      ["crear_sala", "tiempo_turno=" <> tiempo] ->
        crear_sala_batalla(entrenador, tiempo, especies, movs, tienda, batalla_actual, sala_intercambio)

      ["listar_salas"] ->
        IO.puts(listar_salas_batalla())
        bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)

      ["unirse_batalla", codigo] ->
        case unirse_batalla(codigo, entrenador) do
          {:ok, msg} ->
            IO.puts(msg)
            bucle_principal(entrenador, especies, movs, tienda, codigo, sala_intercambio)

          {:error, msg} ->
            IO.puts(msg)
            bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)
        end

      ["unirse_sala", codigo] ->
        case unirse_batalla(codigo, entrenador) do
          {:ok, msg} ->
            IO.puts(msg)
            bucle_principal(entrenador, especies, movs, tienda, codigo, sala_intercambio)

          {:error, msg} ->
            IO.puts(msg)
            bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)
        end

      ["iniciar_batalla", codigo] ->
        IO.puts(iniciar_batalla(codigo))
        bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)

      # ── ACCIONES DE BATALLA ──

      ["atacar", movimiento] ->
        case batalla_actual do
          nil ->
            IO.puts("No estás en una batalla activa")

          codigo ->
            case Batalla.atacar(codigo, entrenador.nombre, movimiento) do
              :ok -> IO.puts("✅ Ataque ejecutado")
              :esperando -> IO.puts("⏳ Acción registrada, esperando al rival...")
              {:error, msg} -> IO.puts("❌ #{msg}")
            end
        end

        bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)

      ["cambiar", pokemon_id] ->
        case batalla_actual do
          nil ->
            IO.puts("No estás en una batalla activa")

          codigo ->
            case Batalla.cambiar(codigo, entrenador.nombre, String.to_integer(pokemon_id)) do
              :ok -> IO.puts("✅ Cambio ejecutado")
              :esperando -> IO.puts("⏳ Acción registrada, esperando al rival...")
              {:error, msg} -> IO.puts("❌ #{msg}")
            end
        end

        bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)

      ["pasar"] ->
        case batalla_actual do
          nil ->
            IO.puts("No estás en una batalla activa")

          codigo ->
            case Batalla.pasar(codigo, entrenador.nombre) do
              :ok -> IO.puts("✅ Turno pasado")
              :esperando -> IO.puts("⏳ Acción registrada, esperando al rival...")
              {:error, msg} -> IO.puts("❌ #{msg}")
            end
        end

        bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)

      ["rendirse"] ->
        case batalla_actual do
          nil ->
            IO.puts("No estás en una batalla activa")
            bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)

          codigo ->
            case Batalla.rendirse(codigo, entrenador.nombre) do
              :ok -> IO.puts("🏳️  Te has rendido.")
              {:error, msg} -> IO.puts("❌ #{msg}")
            end

            bucle_principal(entrenador, especies, movs, tienda, nil, sala_intercambio)
        end

      # ── INTERCAMBIO ──

      ["crear_sala_intercambio"] ->
        case GestorSalas.crear_sala_intercambio(entrenador.nombre) do
          {:ok, codigo} ->
            IO.puts("[Sala #{codigo} creada] Comparte este código con el otro entrenador.")
            bucle_principal(entrenador, especies, movs, tienda, batalla_actual, codigo)

          {:error, msg} ->
            IO.puts(msg)
            bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)
        end

      ["unirse_sala_intercambio", codigo] ->
        case GestorSalas.unirse_sala_intercambio(codigo, entrenador.nombre) do
          {:ok, msg} ->
            IO.puts(msg)
            bucle_principal(entrenador, especies, movs, tienda, batalla_actual, codigo)

          {:error, msg} ->
            IO.puts(msg)
            bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)
        end

      ["ofrecer_pokemon", id] ->
        case sala_intercambio do
          nil ->
            IO.puts("No estás en una sala de intercambio")

          codigo ->
            case GestorSalas.ofrecer_pokemon(codigo, entrenador.nombre, String.to_integer(id)) do
              {:ok, msg} -> IO.puts(msg)
              {:error, msg} -> IO.puts(msg)
            end
        end

        bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)

      ["confirmar_intercambio"] ->
        case sala_intercambio do
          nil ->
            IO.puts("No estás en una sala de intercambio")
            bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)

          codigo ->
            case GestorSalas.confirmar_intercambio(codigo, entrenador.nombre) do
              {:ok, msg} ->
                IO.puts(msg)
                nueva_sala =
                  if String.starts_with?(msg, "[Intercambio completado]"), do: nil, else: codigo
                entrenador_actualizado = refrescar_entrenador(entrenador)
                bucle_principal(entrenador_actualizado, especies, movs, tienda, batalla_actual, nueva_sala)

              {:error, msg} ->
                IO.puts(msg)
                bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)
            end
        end

      ["cancelar_intercambio"] ->
        case sala_intercambio do
          nil ->
            IO.puts("No estás en una sala de intercambio")
            bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)

          codigo ->
            case GestorSalas.cancelar_intercambio(codigo, entrenador.nombre) do
              {:ok, msg} ->
                IO.puts(msg)
                bucle_principal(entrenador, especies, movs, tienda, batalla_actual, nil)

              {:error, msg} ->
                IO.puts(msg)
                bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)
            end
        end

      ["salir"] ->
        GestorEntrenadores.guardar_entrenador(entrenador)
        IO.puts("Guardado. Adiós #{entrenador.nombre}")

      _ ->
        IO.puts("Comando no válido. Escribe 'ayuda' para ver los comandos disponibles.")
        bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)
    end
  end

  def crear_batalla(entrenador) do
    with {:ok, preparado} <- GestorEntrenadores.equipo_para_batalla(entrenador) do
      crear_batalla_con_reintento(preparado, 20_000)
    end
  end

  def unirse_batalla(codigo, entrenador) do
    with {:ok, preparado} <- GestorEntrenadores.equipo_para_batalla(entrenador) do
      try do
        case Batalla.unirse(codigo, preparado) do
          :ok -> {:ok, "[Batalla #{codigo}] #{entrenador.nombre} se ha unido."}
          {:error, msg} -> {:error, msg}
        end
      catch
        :exit, {:noproc, _} -> {:error, "No existe una batalla con código #{codigo}"}
      end
    end
  end

  def iniciar_batalla(codigo) do
    try do
      case Batalla.estado(codigo) do
        %{jugadores: jugadores} when map_size(jugadores) == 2 -> "Batalla #{codigo} lista"
        %{jugadores: _} -> "Faltan jugadores para iniciar la batalla #{codigo}"
        _ -> "No existe una batalla con código #{codigo}"
      end
    catch
      :exit, {:noproc, _} -> "No existe una batalla con código #{codigo}"
    end
  end

  defp crear_batalla_con_reintento(entrenador, tiempo_turno) do
    codigo = generar_codigo_batalla()

    case SupervisorBatallas.crear_batalla(codigo, entrenador, tiempo_turno: tiempo_turno) do
      {:ok, _pid} ->
        {:ok, codigo}

      {:error, {:already_started, _pid}} ->
        crear_batalla_con_reintento(entrenador, tiempo_turno)

      {:error, reason} ->
        {:error, formatear_error_batalla(reason)}
    end
  end

  defp crear_sala_batalla(entrenador, tiempo, especies, movs, tienda, batalla_actual, sala_intercambio) do
    tiempo_turno = normalizar_tiempo(tiempo)

    case GestorEntrenadores.equipo_para_batalla(entrenador) do
      {:ok, preparado} ->
        case crear_batalla_con_reintento(preparado, tiempo_turno) do
          {:ok, codigo} ->
            IO.puts("[Batalla #{codigo} creada] Comparte este código con el otro entrenador.")
            bucle_principal(entrenador, especies, movs, tienda, codigo, sala_intercambio)

          {:error, msg} ->
            IO.puts(msg)
            bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)
        end

      {:error, msg} ->
        IO.puts(msg)
        bucle_principal(entrenador, especies, movs, tienda, batalla_actual, sala_intercambio)
    end
  end

  defp listar_salas_batalla do
    SupervisorBatallas.salas_activas()
    |> Enum.filter(&String.starts_with?(&1, "B-"))
    |> case do
      [] -> "No hay salas disponibles"
      salas -> Enum.map_join(salas, "\n", &"- #{&1}")
    end
  end

  defp generar_codigo_batalla do
    node_tag = Node.self() |> Atom.to_string() |> Base.url_encode64(padding: false)
    "B-" <> node_tag <> "-" <> Integer.to_string(:erlang.unique_integer([:positive, :monotonic]))
  end

  defp mostrar_tienda(tienda) do
    IO.puts("\n=== TIENDA ===")

    Enum.each(tienda, fn {tipo, datos} ->
      probs = datos["probabilidades"] || %{}
      IO.puts("#{tipo} - #{datos["precio"]} monedas | común #{probs["comun"]}% / raro #{probs["raro"]}% / épico #{probs["epico"]}%")
    end)
  end

  defp comprar_sobre(entrenador, tipo, tienda) do
    case Map.fetch(tienda, tipo) do
      {:ok, datos} ->
        precio = datos["precio"]

        if entrenador.monedas >= precio do
          nuevo_sobre = %{"id" => generar_id_sobre(), "tipo" => tipo}
          actualizado = %{entrenador | monedas: entrenador.monedas - precio, sobres_pendientes: entrenador.sobres_pendientes ++ [nuevo_sobre]}
          :ok = GestorEntrenadores.guardar_entrenador(actualizado)
          IO.puts("Compraste sobre #{tipo}")
          actualizado
        else
          IO.puts("No tienes monedas suficientes")
          entrenador
        end

      :error ->
        IO.puts("Tipo inválido. Usa 'tienda ' para ver los disponibles.")
        entrenador
    end
  end

  defp abrir_sobre(entrenador, selector, especies, movs, tienda) do
    case seleccionar_sobre(entrenador.sobres_pendientes, selector) do
      nil ->
        IO.puts("No tienes ese sobre")
        entrenador

      sobre ->
        nuevos = PokemonBattle.SistemaSobres.abrir_sobre(entrenador.nombre, sobre["tipo"], especies, movs, tienda)
        IO.puts("\n¡Sobre abierto! Obtuviste:")

        Enum.each(nuevos, fn p ->
          tipos = Enum.map_join(List.wrap(p.tipos), "/", &String.capitalize/1)
          IO.puts("[##{p.id}] #{String.capitalize(p.especie)} (#{tipos}) [#{p.rareza}] - Dueño original: #{p.dueño_original}")
          IO.puts("  Movimientos: #{movs}")
        end)

        sobres_restantes = Enum.reject(entrenador.sobres_pendientes, &(&1["id"] == sobre["id"]))
        actualizado = %{entrenador | coleccion: entrenador.coleccion ++ nuevos, sobres_pendientes: sobres_restantes}
        :ok = GestorEntrenadores.guardar_entrenador(actualizado)
        actualizado
    end
  end

  defp seleccionar_sobre([], _selector), do: nil
  defp seleccionar_sobre(sobres, "ultimo"), do: List.last(sobres)
  defp seleccionar_sobre(sobres, selector) do
    case Integer.parse(selector) do
      {id, ""} -> Enum.find(sobres, &(&1["id"] == id))
      _ -> nil
    end
  end

  defp refrescar_entrenador(entrenador) do
    GestorEntrenadores.buscar_entrenador(entrenador.nombre) || entrenador
  end

  defp generar_id_sobre do
    :erlang.unique_integer([:positive, :monotonic])
  end

  defp normalizar_tiempo(nil), do: 20_000
  defp normalizar_tiempo(tiempo) when is_binary(tiempo) do
    case Integer.parse(tiempo) do
      {n, ""} when n < 1000 -> n * 1000
      {n, ""} -> n
      _ -> 20_000
    end
  end
  defp normalizar_tiempo(tiempo) when is_integer(tiempo) and tiempo < 1000, do: tiempo * 1000
  defp normalizar_tiempo(tiempo) when is_integer(tiempo), do: tiempo
  defp normalizar_tiempo(_), do: 20_000

  defp formatear_error_batalla(reason) when is_binary(reason), do: reason
  defp formatear_error_batalla({:shutdown, inner}), do: formatear_error_batalla(inner)
  defp formatear_error_batalla(reason), do: inspect(reason)
end

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
          %{} = entrenador -> bucle_principal(entrenador, especies, movs, tienda, nil)
          {:error, msg} -> IO.puts(msg); bucle_login(especies, movs, tienda)
        end

      ["iniciar", nombre] ->
        case GestorEntrenadores.iniciar_sesion(nombre, "") do
          %{} = entrenador -> bucle_principal(entrenador, especies, movs, tienda, nil)
          {:error, msg} -> IO.puts(msg); bucle_login(especies, movs, tienda)
        end

      ["salir"] ->
        IO.puts("¡Hasta luego!")

      _ ->
        IO.puts("Usa: iniciar <usuario> <clave>")
        bucle_login(especies, movs, tienda)
    end
  end

  defp bucle_principal(entrenador, especies, movs, tienda, sala_actual) do
    IO.puts("\nComandos:")
    IO.puts("perfil | inventario | clasificacion | tienda")
    IO.puts("comprar_sobre <tipo> | abrir_sobre <id_sobre|ultimo>")
    IO.puts("crear_equipo <nombre> <id1[,id2,id3]> | listar_equipos")
    IO.puts("usar_equipo <nombre> | agregar_pokemon_equipo <nombre> <id> | quitar_pokemon_equipo <nombre> <id>")
    IO.puts("crear_batalla [tiempo_turno=20] | unirse_batalla <codigo> | iniciar_batalla <codigo>")
    IO.puts("crear_sala_intercambio | unirse_sala_intercambio <codigo>")
    IO.puts("ofrecer_pokemon <id> | confirmar_intercambio | cancelar_intercambio")
    IO.puts("salir")

    comando = IO.gets("\n> ") |> String.trim()

    case String.split(comando) do
      ["perfil"] ->
        GestorEntrenadores.perfil(entrenador)
        bucle_principal(entrenador, especies, movs, tienda, sala_actual)

      ["inventario"] ->
        GestorEntrenadores.inventario(entrenador, especies)
        bucle_principal(entrenador, especies, movs, tienda, sala_actual)

      ["clasificacion"] ->
        entrenadores = GestorEntrenadores.cargar_todos()
        clasificacion = GestorEntrenadores.clasificacion(entrenadores)

        IO.puts("\n=== Clasificación Global ===")
        IO.puts("# | Entrenador | Victorias | Monedas acumuladas")
        IO.puts(String.duplicate("-", 45))

        Enum.each(clasificacion, fn {i, e} ->
          IO.puts("#{i} | #{e.nombre} | #{e.victorias} | #{e.monedas_acumuladas}")
        end)

        bucle_principal(entrenador, especies, movs, tienda, sala_actual)

      ["tienda"] ->
        mostrar_tienda(tienda)
        bucle_principal(entrenador, especies, movs, tienda, sala_actual)

      ["comprar_sobre", tipo] ->
        entrenador_actualizado = comprar_sobre(entrenador, tipo, tienda)
        bucle_principal(entrenador_actualizado, especies, movs, tienda, sala_actual)

      ["abrir_sobre"] ->
        entrenador_actualizado = abrir_sobre(entrenador, "ultimo", especies, movs, tienda)
        bucle_principal(entrenador_actualizado, especies, movs, tienda, sala_actual)

      ["abrir_sobre", selector] ->
        entrenador_actualizado = abrir_sobre(entrenador, selector, especies, movs, tienda)
        bucle_principal(entrenador_actualizado, especies, movs, tienda, sala_actual)

      ["crear_equipo", nombre, ids] ->
        entrenador_actualizado =
          case GestorEntrenadores.crear_equipo(entrenador, nombre, ids) do
            {:ok, updated} -> IO.puts("Equipo #{nombre} creado"); updated
            {:error, msg} -> IO.puts(msg); entrenador
          end

        bucle_principal(refrescar_entrenador(entrenador_actualizado), especies, movs, tienda, sala_actual)

      ["listar_equipos"] ->
        IO.puts(GestorEntrenadores.listar_equipos(entrenador))
        bucle_principal(entrenador, especies, movs, tienda, sala_actual)

      ["usar_equipo", nombre] ->
        case GestorEntrenadores.usar_equipo(entrenador, nombre) do
          {:ok, updated} ->
            IO.puts("Equipo #{nombre} seleccionado")
            bucle_principal(updated, especies, movs, tienda, sala_actual)

          {:error, msg} ->
            IO.puts(msg)
            bucle_principal(entrenador, especies, movs, tienda, sala_actual)
        end

      ["agregar_pokemon_equipo", nombre, id] ->
        case GestorEntrenadores.agregar_pokemon_equipo(entrenador, nombre, String.to_integer(id)) do
          {:ok, updated} ->
            IO.puts("Pokémon agregado al equipo")
            bucle_principal(updated, especies, movs, tienda, sala_actual)

          {:error, msg} ->
            IO.puts(msg)
            bucle_principal(entrenador, especies, movs, tienda, sala_actual)
        end

      ["quitar_pokemon_equipo", nombre, id] ->
        case GestorEntrenadores.quitar_pokemon_equipo(entrenador, nombre, String.to_integer(id)) do
          {:ok, updated} ->
            IO.puts("Pokémon quitado del equipo")
            bucle_principal(updated, especies, movs, tienda, sala_actual)

          {:error, msg} ->
            IO.puts(msg)
            bucle_principal(entrenador, especies, movs, tienda, sala_actual)
        end

      ["crear_sala"] ->
        crear_sala_batalla(entrenador, nil, especies, movs, tienda, sala_actual)

      ["crear_sala", "tiempo_turno=" <> tiempo] ->
        crear_sala_batalla(entrenador, tiempo, especies, movs, tienda, sala_actual)

      ["crear_batalla"] ->
        crear_sala_batalla(entrenador, nil, especies, movs, tienda, sala_actual)

      ["crear_batalla", "tiempo_turno=" <> tiempo] ->
        crear_sala_batalla(entrenador, tiempo, especies, movs, tienda, sala_actual)

      ["listar_salas"] ->
        IO.puts(listar_salas_batalla())
        bucle_principal(entrenador, especies, movs, tienda, sala_actual)

      ["unirse_sala", codigo] ->
        case unirse_batalla(codigo, entrenador) do
          {:ok, msg} -> IO.puts(msg)
          {:error, msg} -> IO.puts(msg)
        end

        bucle_principal(entrenador, especies, movs, tienda, sala_actual)

      ["unirse_batalla", codigo] ->
        case unirse_batalla(codigo, entrenador) do
          {:ok, msg} -> IO.puts(msg)
          {:error, msg} -> IO.puts(msg)
        end

        bucle_principal(entrenador, especies, movs, tienda, sala_actual)

      ["iniciar_batalla", codigo] ->
        IO.puts(iniciar_batalla(codigo))
        bucle_principal(entrenador, especies, movs, tienda, sala_actual)

      ["crear_sala_intercambio"] ->
        case GestorSalas.crear_sala_intercambio(entrenador.nombre) do
          {:ok, codigo} ->
            IO.puts("[Sala #{codigo} creada] Comparte este código con el otro entrenador.")
            bucle_principal(entrenador, especies, movs, tienda, codigo)

          {:error, msg} ->
            IO.puts(msg)
            bucle_principal(entrenador, especies, movs, tienda, sala_actual)
        end

      ["unirse_sala_intercambio", codigo] ->
        case GestorSalas.unirse_sala_intercambio(codigo, entrenador.nombre) do
          {:ok, msg} ->
            IO.puts(msg)
            bucle_principal(entrenador, especies, movs, tienda, codigo)

          {:error, msg} ->
            IO.puts(msg)
            bucle_principal(entrenador, especies, movs, tienda, sala_actual)
        end

      ["ofrecer_pokemon", id] ->
        if sala_actual do
          case GestorSalas.ofrecer_pokemon(sala_actual, entrenador.nombre, String.to_integer(id)) do
            {:ok, msg} -> IO.puts(msg)
            {:error, msg} -> IO.puts(msg)
          end
        else
          IO.puts("No estás en una sala")
        end

        bucle_principal(entrenador, especies, movs, tienda, sala_actual)

      ["confirmar_intercambio"] ->
        if sala_actual do
          case GestorSalas.confirmar_intercambio(sala_actual, entrenador.nombre) do
            {:ok, msg} ->
              IO.puts(msg)

              nueva_sala_actual =
                if String.starts_with?(msg, "[Intercambio completado]") do
                  nil
                else
                  sala_actual
                end

              bucle_principal(entrenador, especies, movs, tienda, nueva_sala_actual)

            {:error, msg} ->
              IO.puts(msg)
              bucle_principal(entrenador, especies, movs, tienda, sala_actual)
          end
        else
          IO.puts("No estás en una sala")
          bucle_principal(entrenador, especies, movs, tienda, sala_actual)
        end

      ["cancelar_intercambio"] ->
        if sala_actual do
          case GestorSalas.cancelar_intercambio(sala_actual, entrenador.nombre) do
            {:ok, msg} ->
              IO.puts(msg)
              bucle_principal(entrenador, especies, movs, tienda, nil)

            {:error, msg} ->
              IO.puts(msg)
              bucle_principal(entrenador, especies, movs, tienda, sala_actual)
          end
        else
          IO.puts("No estás en una sala")
          bucle_principal(entrenador, especies, movs, tienda, sala_actual)
        end

      ["salir"] ->
        GestorEntrenadores.guardar_entrenador(entrenador)
        IO.puts("Guardado. Adiós #{entrenador.nombre}")

      _ ->
        IO.puts("Comando no válido")
        bucle_principal(entrenador, especies, movs, tienda, sala_actual)
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

  defp crear_sala_batalla(entrenador, tiempo, especies, movs, tienda, sala_actual) do
    tiempo_turno = normalizar_tiempo(tiempo)

    case GestorEntrenadores.equipo_para_batalla(entrenador) do
      {:ok, preparado} ->
        case crear_batalla_con_reintento(preparado, tiempo_turno) do
          {:ok, codigo} ->
            IO.puts("[Batalla #{codigo} creada] Comparte este código con el otro entrenador.")
            bucle_principal(entrenador, especies, movs, tienda, sala_actual)

          {:error, msg} ->
            IO.puts(msg)
            bucle_principal(entrenador, especies, movs, tienda, sala_actual)
        end

      {:error, msg} ->
        IO.puts(msg)
        bucle_principal(entrenador, especies, movs, tienda, sala_actual)
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
        IO.puts("Tipo inválido")
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

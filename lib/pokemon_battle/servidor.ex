defmodule PokemonBattle.Servidor do
  alias PokemonBattle.{GestorEntrenadores, Persistencia, GestorSalas}

  def iniciar do
    movs_base  = Persistencia.cargar_datos("data/moves.json")
    tienda     = Persistencia.cargar_datos("data/tienda.json")
    especies   = Persistencia.cargar_especies("data/pokemon.json")

    IO.puts("==================================")
    IO.puts("   BIENVENIDO A POKÉMON BATTLE    ")
    IO.puts("==================================")

    bucle_login(especies, movs_base, tienda)
  end

  # =========================
  # LOGIN
  # =========================

  defp bucle_login(especies, movs, tienda) do
    comando = IO.gets("\n> ") |> String.trim()

    case String.split(comando) do
      ["iniciar", nombre] ->
        entrenador = GestorEntrenadores.iniciar_sesion(nombre)
        bucle_principal(entrenador, especies, movs, tienda, nil)

      ["salir"] ->
        IO.puts("¡Hasta luego!")

      _ ->
        IO.puts("Usa: iniciar <usuario>")
        bucle_login(especies, movs, tienda)
    end
  end

  # =========================
  # MENU PRINCIPAL
  # =========================

  defp bucle_principal(entrenador, especies, movs, tienda, sala_actual) do
    IO.puts("\nComandos:")
    IO.puts("perfil | inventario | clasificacion | tienda")
    IO.puts("comprar_sobre <tipo> | abrir_sobre")
    IO.puts("crear_sala_intercambio | unirse_sala_intercambio <codigo>")
    IO.puts("ofrecer_pokemon <id> | confirmar_intercambio | cancelar_intercambio")
    IO.puts("salir")

    comando = IO.gets("\n> ") |> String.trim()

    case String.split(comando) do
      # -------- PERFIL --------

      ["perfil"] ->
        GestorEntrenadores.perfil(entrenador)
        bucle_principal(entrenador, especies, movs, tienda, sala_actual)

      ["inventario"] ->
        GestorEntrenadores.inventario(entrenador, especies)
        bucle_principal(entrenador, especies, movs, tienda, sala_actual)

      ["clasificacion"] ->
        entrenadores = GestorEntrenadores.cargar_todos()
        ordenados = Enum.sort_by(entrenadores, fn e ->
          {-e.victorias, -e.monedas_acumuladas}
       end)
      IO.puts("\n=== Clasificación Global ===")
      IO.puts("# | Entrenador | Victorias | Monedas acumuladas")
      IO.puts(String.duplicate("-", 45))
      Enum.with_index(ordenados, 1) |> Enum.each(fn {e, i} ->
        IO.puts("#{i} | #{e.nombre} | #{e.victorias} | #{e.monedas_acumuladas}")
      end)
      bucle_principal(entrenador, especies, movs, tienda, sala_actual)
        # -------- TIENDA --------

      ["tienda"] ->
        mostrar_tienda(tienda)
        bucle_principal(entrenador, especies, movs, tienda, sala_actual)

      ["comprar_sobre", tipo] ->
        entrenador = comprar_sobre(entrenador, tipo, tienda)
        bucle_principal(entrenador, especies, movs, tienda, sala_actual)

      ["abrir_sobre"] ->
        entrenador = abrir_sobre(entrenador, especies, movs, tienda)
        bucle_principal(entrenador, especies, movs, tienda, sala_actual)

      # =========================
      # INTERCAMBIOS
      # =========================

      ["crear_sala_intercambio"] ->
        case GestorSalas.crear_sala_intercambio(entrenador.nombre) do
          {:ok, codigo} ->
            IO.puts("[Sala #{codigo} creada]")
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
          case GestorSalas.ofrecer_pokemon(
                 sala_actual,
                 entrenador.nombre,
                 String.to_integer(id)
               ) do
            {:ok, msg} -> IO.puts(msg)
            {:error, msg} -> IO.puts(msg)
          end
        else
          IO.puts("No estás en una sala")
        end

        bucle_principal(entrenador, especies, movs, tienda, sala_actual)

      ["confirmar_intercambio"] ->
        if sala_actual do
          case GestorSalas.confirmar_intercambio(
                 sala_actual,
                 entrenador.nombre
               ) do
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

      ["cancelar_intercambio"] ->
        if sala_actual do
          GestorSalas.cancelar_intercambio(
            sala_actual,
            entrenador.nombre
          )

          IO.puts("Sala cancelada")
          bucle_principal(entrenador, especies, movs, tienda, nil)
        else
          IO.puts("No estás en una sala")
          bucle_principal(entrenador, especies, movs, tienda, sala_actual)
        end

      # -------- SALIR --------

      ["salir"] ->
        GestorEntrenadores.guardar_entrenador(entrenador)
        IO.puts("Guardado. Adiós #{entrenador.nombre}")

      _ ->
        IO.puts("Comando no válido")
        bucle_principal(entrenador, especies, movs, tienda, sala_actual)
    end
  end

  # =========================
  # TIENDA
  # =========================

  defp mostrar_tienda(tienda) do
    IO.puts("\n=== TIENDA ===")

    Enum.each(tienda, fn {tipo, datos} ->
      IO.puts("#{tipo} - #{datos["precio"]} monedas")
    end)
  end

  # =========================
  # COMPRAR SOBRE
  # =========================

  defp comprar_sobre(entrenador, tipo, tienda) do
    if Map.has_key?(tienda, tipo) do
      precio = tienda[tipo]["precio"]

      if entrenador.monedas >= precio do
        nuevo_sobre = %{
          "id" => :rand.uniform(100_000),
          "tipo" => tipo
        }

        actualizado = %{
          entrenador |
          monedas: entrenador.monedas - precio,
          sobres_pendientes: entrenador.sobres_pendientes ++ [nuevo_sobre]
        }

        GestorEntrenadores.guardar_entrenador(actualizado)

        IO.puts("Compraste sobre #{tipo}")
        actualizado
      else
        IO.puts("No tienes monedas suficientes")
        entrenador
      end
    else
      IO.puts("Tipo inválido")
      entrenador
    end
  end

  # =========================
  # ABRIR SOBRE
  # =========================

  defp abrir_sobre(entrenador, especies, movs, tienda) do
    case entrenador.sobres_pendientes do
      [] ->
        IO.puts("No tienes sobres")
        entrenador

      [sobre | resto] ->
        nuevos =
          PokemonBattle.SistemaSobres.abrir_sobre(
            entrenador.nombre,
            sobre["tipo"],
            especies,
            movs,
            tienda
          )

        IO.puts("\n¡Sobre abierto! Obtuviste:")

        Enum.each(nuevos, fn p ->
          IO.puts("#{p.especie} (#{p.rareza})")
        end)

        actualizado = %{
          entrenador |
          coleccion: entrenador.coleccion ++ nuevos,
          sobres_pendientes: resto
        }

        GestorEntrenadores.guardar_entrenador(actualizado)
        actualizado
    end
  end
end

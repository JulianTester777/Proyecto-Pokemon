defmodule PokemonBattle.Servidor do
  alias PokemonBattle.{GestorEntrenadores, Persistencia, SistemaSobres}

  def iniciar do
    pokes_base = Persistencia.cargar_datos("data/pokemon.json")
    movs_base  = Persistencia.cargar_datos("data/moves.json")
    tienda     = Persistencia.cargar_datos("data/tienda.json")

    IO.puts("==================================")
    IO.puts("   BIENVENIDO A POKÉMON BATTLE    ")
    IO.puts("==================================")

    bucle_login(pokes_base, movs_base, tienda)
  end

  # LOGIN

  defp bucle_login(pokes, movs, tienda) do
    comando = IO.gets("\n> ") |> String.trim()

    case String.split(comando) do
      ["iniciar", nombre] ->
        entrenador = GestorEntrenadores.iniciar_sesion(nombre)
        bucle_principal(entrenador, pokes, movs, tienda)

      ["salir"] ->
        IO.puts("¡Hasta luego!")

      _ ->
        IO.puts("Usa: iniciar <usuario>")
        bucle_login(pokes, movs, tienda)
    end
  end

  # MENU PRINCIPAL

  defp bucle_principal(entrenador, pokes, movs, tienda) do
    IO.puts("\nComandos:")
    IO.puts("perfil | inventario | tienda")
    IO.puts("comprar_sobre <tipo> | abrir_sobre")
    IO.puts("salir")

    comando = IO.gets("\n> ") |> String.trim()

    case String.split(comando) do
      ["perfil"] ->
        GestorEntrenadores.perfil(entrenador)
        bucle_principal(entrenador, pokes, movs, tienda)

      ["inventario"] ->
        GestorEntrenadores.inventario(entrenador)
        bucle_principal(entrenador, pokes, movs, tienda)

      ["tienda"] ->
        mostrar_tienda(tienda)
        bucle_principal(entrenador, pokes, movs, tienda)

      ["comprar_sobre", tipo] ->
        entrenador = comprar_sobre(entrenador, tipo, tienda)
        bucle_principal(entrenador, pokes, movs, tienda)

      ["abrir_sobre"] ->
        entrenador = abrir_sobre(entrenador, pokes, movs, tienda)
        bucle_principal(entrenador, pokes, movs, tienda)

      ["salir"] ->
        GestorEntrenadores.guardar_entrenador(entrenador)
        IO.puts("Guardado. Adiós #{entrenador.nombre}")

      _ ->
        IO.puts("Comando no válido")
        bucle_principal(entrenador, pokes, movs, tienda)
    end
  end

  # TIENDA

  defp mostrar_tienda(tienda) do
    IO.puts("\n=== TIENDA ===")

    Enum.each(tienda, fn {tipo, datos} ->
      IO.puts("#{tipo} - #{datos["precio"]} monedas")
    end)
  end

  # COMPRAR SOBRE

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


  defp abrir_sobre(entrenador, pokes, movs, tienda) do
    case entrenador.sobres_pendientes do
      [] ->
        IO.puts("No tienes sobres")
        entrenador

      [sobre | resto] ->
        nuevos =
          SistemaSobres.abrir_sobre(
            entrenador.nombre,
            sobre["tipo"],
            pokes,
            movs,
            tienda
          )

        IO.puts("\n¡Sobre abierto! Obtuviste:")

        Enum.each(nuevos, fn p ->
          IO.puts("#{p.especie} (#{p.rareza})")
        end)

        nuevos_maps =
          Enum.map(nuevos, fn p ->
            %{
              "id" => p.id,
              "especie" => p.especie,
              "rareza" => to_string(p.rareza),
              "ataque" => p.ataque,
              "defensa" => p.defensa,
              "velocidad" => p.velocidad,
              "movimientos" => Enum.map(p.movimientos, &Map.from_struct/1),
              "dueño_original" => p.dueño_original
            }
          end)

        actualizado = %{
          entrenador |
          coleccion: entrenador.coleccion ++ nuevos_maps,
          sobres_pendientes: resto
        }

        GestorEntrenadores.guardar_entrenador(actualizado)
        actualizado
    end
  end
end

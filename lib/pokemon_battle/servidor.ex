defmodule PokemonBattle.Servidor do
  alias PokemonBattle.{GestorEntrenadores, Persistencia, SistemaSobres}

  def iniciar do
    pokes_base = Persistencia.cargar_datos("data/pokemon.json")
    movs_base  = Persistencia.cargar_datos("data/moves.json")
    tienda     = Persistencia.cargar_datos("data/tienda.json")

    IO.puts("==================================")
    IO.puts("   BIENVENIDO A POKÉMON BATTLE    ")
    IO.puts("==================================")
    IO.puts("Comandos: iniciar <usuario> | salir")

    bucle_login(pokes_base, movs_base, tienda)
  end

  # ── LOGIN ──────────────────────────────────────────────────────────────────

  defp bucle_login(pokes, movs, tienda) do
    comando = IO.gets("\n> ") |> String.trim()

    case String.split(comando) do
      ["iniciar", nombre] ->
        entrenador = GestorEntrenadores.iniciar_sesion(nombre)
        bucle_principal(entrenador, pokes, movs, tienda)

      ["salir"] ->
        IO.puts("¡Hasta luego!")

      _ ->
        IO.puts("Comando no reconocido. Usa: iniciar <usuario>")
        bucle_login(pokes, movs, tienda)
    end
  end

  # ── BUCLE PRINCIPAL ────────────────────────────────────────────────────────

  defp bucle_principal(entrenador, pokes, movs, tienda) do
    IO.puts("\nComandos disponibles:")
    IO.puts("  perfil | inventario | clasificacion")
    IO.puts("  tienda | comprar_sobre <tipo> | abrir_sobre <id|ultimo>")
    IO.puts("  salir")

    comando = IO.gets("\n> ") |> String.trim()
    partes  = String.split(comando)

    case partes do
      ["perfil"] ->
        GestorEntrenadores.perfil(entrenador)
        bucle_principal(entrenador, pokes, movs, tienda)

      ["inventario"] ->
        GestorEntrenadores.inventario(entrenador)
        bucle_principal(entrenador, pokes, movs, tienda)

      ["clasificacion"] ->
        GestorEntrenadores.clasificacion()
        bucle_principal(entrenador, pokes, movs, tienda)

      ["tienda"] ->
        mostrar_tienda(tienda)
        bucle_principal(entrenador, pokes, movs, tienda)

      ["comprar_sobre", tipo] ->
        entrenador = comprar_sobre(entrenador, tipo, tienda)
        bucle_principal(entrenador, pokes, movs, tienda)

      ["abrir_sobre", ref] ->
        entrenador = abrir_sobre(entrenador, ref, pokes, movs, tienda)
        bucle_principal(entrenador, pokes, movs, tienda)

      ["salir"] ->
        GestorEntrenadores.guardar_entrenador(entrenador)
        IO.puts("¡Partida guardada! Adiós, #{entrenador["nombre"]}.")

      _ ->
        IO.puts("Comando no reconocido.")
        bucle_principal(entrenador, pokes, movs, tienda)
    end
  end

  # ── TIENDA ─────────────────────────────────────────────────────────────────

  defp mostrar_tienda(tienda) do
    IO.puts("\n=== Tienda ===")
    IO.puts("Tipo       Precio   Común   Raro   Épico")

    Enum.each(tienda, fn {tipo, datos} ->
      p = datos["probabilidades"]
      IO.puts("#{String.pad_trailing(tipo, 10)} #{String.pad_leading(to_string(datos["precio"]), 6)}   #{p["comun"]}%    #{p["raro"]}%    #{p["epico"]}%")
    end)
  end

  # ── COMPRAR SOBRE ──────────────────────────────────────────────────────────

  defp comprar_sobre(entrenador, tipo, tienda) do
    if Map.has_key?(tienda, tipo) do
      precio = tienda[tipo]["precio"]

      if entrenador["monedas"] >= precio do
        nuevo_sobre = %{"id" => :rand.uniform(100_000), "tipo" => tipo}

        entrenador_actualizado = %{entrenador |
          "monedas"           => entrenador["monedas"] - precio,
          "sobres_pendientes" => entrenador["sobres_pendientes"] ++ [nuevo_sobre]
        }

        GestorEntrenadores.guardar_entrenador(entrenador_actualizado)
        IO.puts("¡Sobre #{tipo} comprado! ID: #{nuevo_sobre["id"]}")
        entrenador_actualizado
      else
        IO.puts("No tienes suficientes monedas. Necesitas #{precio}, tienes #{entrenador["monedas"]}.")
        entrenador
      end
    else
      IO.puts("Tipo de sobre no válido. Usa: basico | avanzado")
      entrenador
    end
  end

  # ── ABRIR SOBRE ────────────────────────────────────────────────────────────

  defp abrir_sobre(entrenador, ref, pokes, movs, tienda) do
    sobres = entrenador["sobres_pendientes"]

    sobre = case ref do
      "ultimo" -> List.last(sobres)
      id_str   ->
        id = String.to_integer(id_str)
        Enum.find(sobres, fn s -> s["id"] == id end)
    end

    if sobre do
      nuevos_pkm = SistemaSobres.abrir_sobre(
        entrenador["nombre"],
        sobre["tipo"],
        pokes,
        movs,
        tienda
      )

      IO.puts("\n¡Sobre abierto! Obtuviste:")
      nuevos_pkm
      |> Enum.with_index(1)
      |> Enum.each(fn {pkm, i} ->
        especie   = to_string(pkm.especie)
        tipos     = pkm.tipos || []
        tipos_str = tipos |> Enum.map(&String.capitalize/1) |> Enum.join("/")
        rareza    = to_string(pkm.rareza)
        movs_str  = pkm.movimientos
                    |> Enum.map(fn m -> "#{m["nombre"]} (#{m["poder_base"]})" end)
                    |> Enum.join(", ")

        IO.puts("\n  #{i}. [##{pkm.id}] #{String.capitalize(especie)} (#{tipos_str}) [#{rareza}] - Dueño original: #{pkm.dueño_original}")
        IO.puts("     Movimientos: #{movs_str}")
      end)

      # Serializar Pokémon a mapas para guardar en JSON
      pkm_maps = Enum.map(nuevos_pkm, fn pkm ->
        %{
          "id"            => pkm.id,
          "especie"       => to_string(pkm.especie),
          "tipos"         => pkm.tipos || [],
          "dueño_original"=> pkm.dueño_original,
          "rareza"        => to_string(pkm.rareza),
          "ataque"        => pkm.ataque,
          "defensa"       => pkm.defensa,
          "velocidad"     => pkm.velocidad,
          "salud_maxima"  => 100,
          "movimientos"   => pkm.movimientos
        }
      end)

      sobres_restantes = Enum.reject(sobres, fn s -> s["id"] == sobre["id"] end)

      entrenador_actualizado = %{entrenador |
        "coleccion"         => entrenador["coleccion"] ++ pkm_maps,
        "sobres_pendientes" => sobres_restantes
      }

      GestorEntrenadores.guardar_entrenador(entrenador_actualizado)
      entrenador_actualizado
    else
      IO.puts("Sobre no encontrado. Usa 'perfil' para ver tus sobres pendientes.")
      entrenador
    end
  end
end

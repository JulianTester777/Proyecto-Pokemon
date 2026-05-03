defmodule PokemonBattle.GestorEntrenadores do
  alias PokemonBattle.{Persistencia, Entrenador}

  @archivo "data/trainers.json"

  def cargar_todos do
    Persistencia.cargar_datos(@archivo)
    |> Enum.map(&map_a_struct/1)
  end

  defp map_a_struct(m) do
    %Entrenador{
      nombre: m["nombre"],
      monedas: m["monedas"] || 0,
      monedas_acumuladas: m["monedas_acumuladas"] || 0,
      victorias: m["victorias"] || 0,
      coleccion: Enum.map(m["coleccion"] || [], &map_a_pokemon/1),
      sobres_pendientes: m["sobres_pendientes"] || [],
      equipos: m["equipos"] || []
    }
  end

  defp map_a_pokemon(m) do
    %PokemonBattle.Pokemon{
      id: m["id"],
      especie: m["especie"],
      rareza: String.to_atom(m["rareza"]),
      ataque: m["ataque"],
      defensa: m["defensa"],
      velocidad: m["velocidad"],
      dueño_original: m["dueño_original"],
      movimientos:
        Enum.map(m["movimientos"], fn mov ->
          struct(PokemonBattle.Movimiento, mov)
        end),
      salud_actual: 100,
      salud_maxima: 100
    }
  end

  # -------- LOGIN --------

  def iniciar_sesion(nombre) do
    case Enum.find(cargar_todos(), &(&1.nombre == nombre)) do
      nil ->
        nuevo = %Entrenador{
          nombre: nombre,
          monedas: 0,
          monedas_acumuladas: 0,
          victorias: 0,
          coleccion: [],
          sobres_pendientes: [%{"id" => :rand.uniform(100_000), "tipo" => "basico"}],
          equipos: []
        }

        guardar_entrenador(nuevo)
        IO.puts("Cuenta creada para #{nombre}")
        nuevo

      existente ->
        IO.puts("Bienvenido #{nombre}")
        existente
    end
  end

  # -------- PERFIL --------

  def perfil(entrenador) do
    IO.puts("\n=== Perfil de #{entrenador.nombre} ===")
    IO.puts("Monedas: #{entrenador.monedas}")
    IO.puts("Sobres pendientes: #{length(entrenador.sobres_pendientes)}")
    IO.puts("Pokémon en inventario: #{length(entrenador.coleccion)}")
  end

  # -------- INVENTARIO --------

  def inventario(entrenador, especies) do
    IO.puts("\n=== Inventario de #{entrenador.nombre} ===")

    Enum.each(entrenador.coleccion, fn p ->
      especie = Enum.find(especies, &(&1.especie == p.especie))

      tipos =
        especie.tipos
        |> Enum.map(&String.capitalize/1)
        |> Enum.join("/")

      movs =
        p.movimientos
        |> Enum.map(fn m -> "#{m.nombre}(#{m.poder_base})" end)
        |> Enum.join(", ")

      IO.puts("""
      [##{p.id}] #{String.capitalize(p.especie)} (#{tipos}) [#{p.rareza}]
      Ataque: #{p.ataque} | Defensa: #{p.defensa} | Velocidad: #{p.velocidad}
      Dueño: #{p.dueño_original}
      Movimientos: #{movs}
      """)
    end)
  end

  # -------- GUARDAR --------

  def guardar_entrenador(e) do
    lista = cargar_todos()

    nueva =
      [e | Enum.reject(lista, &(&1.nombre == e.nombre))]
      |> Enum.map(&entrenador_a_map/1)

    Persistencia.guardar_datos(@archivo, nueva)
  end

  defp entrenador_a_map(e) do
    %{
      "nombre" => e.nombre,
      "monedas" => e.monedas,
      "monedas_acumuladas" => e.monedas_acumuladas,
      "victorias" => e.victorias,
      "coleccion" => Enum.map(e.coleccion, &pokemon_a_map/1),
      "sobres_pendientes" => e.sobres_pendientes,
      "equipos" => e.equipos
    }
  end

  defp pokemon_a_map(p) do
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
  end
end

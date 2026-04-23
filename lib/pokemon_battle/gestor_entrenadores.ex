defmodule PokemonBattle.GestorEntrenadores do
  alias PokemonBattle.{Persistencia, Entrenador}

  @archivo "data/trainers.json"

  # CARGAR

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
      coleccion: m["coleccion"] || [],
      sobres_pendientes: m["sobres_pendientes"] || [],
      equipos: m["equipos"] || []
    }
  end

  # LOGIN

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

  # ✅ PERFIL (ESTO ES LO QUE TE FALTABA BIEN)

  def perfil(entrenador) do
    IO.puts("\n=== Perfil de #{entrenador.nombre} ===")
    IO.puts("Monedas: #{entrenador.monedas}")
    IO.puts("Sobres pendientes: #{length(entrenador.sobres_pendientes)}")
    IO.puts("Pokémon en inventario: #{length(entrenador.coleccion)}")
  end

  # INVENTARIO (básico)

  def inventario(entrenador) do
  coleccion = entrenador.coleccion

  IO.puts("\n=== Inventario de #{entrenador.nombre} (#{length(coleccion)} Pokémon) ===")

  if coleccion == [] do
    IO.puts("Tu colección está vacía.")
  else
    coleccion
    |> Enum.with_index(1)
    |> Enum.each(fn {p, i} ->
      tipos =
        (p["tipos"] || [])
        |> Enum.map(&String.capitalize/1)
        |> Enum.join("/")

      movs =
        p["movimientos"]
        |> Enum.map(fn m -> "#{m["nombre"]}(#{m["poder_base"]})" end)
        |> Enum.join(", ")

      IO.puts("""

  #{i}. [##{p["id"]}] #{String.capitalize(p["especie"])} (#{tipos}) [#{p["rareza"]}]
     Ataque: #{p["ataque"]} | Defensa: #{p["defensa"]} | Velocidad: #{p["velocidad"]} | Salud máx: 100
     Dueño original: #{p["dueño_original"]}
     Movimientos: #{movs}
      """)
    end)
  end
end
  # GUARDAR

  def guardar_entrenador(e) do
    lista = cargar_todos()

    nueva =
      [e | Enum.reject(lista, &(&1.nombre == e.nombre))]
      |> Enum.map(&Map.from_struct/1)

    Persistencia.guardar_datos(@archivo, nueva)
  end
end

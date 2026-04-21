defmodule PokemonBattle.GestorEntrenadores do
  alias PokemonBattle.Persistencia

  @archivo_entrenadores "data/trainers.json"

  @doc """
  Carga todos los entrenadores del archivo JSON.
  """
  def cargar_todos do
    case Persistencia.cargar_datos(@archivo_entrenadores) do
      lista when is_list(lista) -> lista
      _ -> []
    end
  end

  @doc """
  Crea un nuevo perfil o carga uno existente por nombre.
  """
  def iniciar_sesion(nombre) do
    entrenadores = cargar_todos()
    entrenador_existente = Enum.find(entrenadores, fn e -> e["nombre"] == nombre end)

    if entrenador_existente do
      IO.puts("¡Bienvenido de nuevo, #{nombre}!")
      entrenador_existente
    else
      IO.puts("Creando perfil nuevo para #{nombre}...")
      nuevo = %{
        "nombre"             => nombre,
        "monedas"            => 0,
        "monedas_acumuladas" => 0,
        "victorias"          => 0,
        "coleccion"          => [],
        "sobres_pendientes"  => [%{"id" => :rand.uniform(100_000), "tipo" => "basico"}]
      }
      guardar_entrenador(nuevo)
      IO.puts("¡Cuenta creada! Recibes 1 sobre básico gratis.")
      nuevo
    end
  end

  @doc """
  Muestra monedas, sobres pendientes y cantidad de Pokémon.
  """
  def perfil(entrenador) do
    IO.puts("\n=== Perfil de #{entrenador["nombre"]} ===")
    IO.puts("Monedas: #{entrenador["monedas"]}")
    IO.puts("Sobres pendientes: #{length(entrenador["sobres_pendientes"])}")
    IO.puts("Pokémon en inventario: #{length(entrenador["coleccion"])}")
  end

  @doc """
  Lista todos los Pokémon del entrenador con atributos completos.
  """
  def inventario(entrenador) do
    coleccion = entrenador["coleccion"]
    IO.puts("\n=== Inventario de #{entrenador["nombre"]} (#{length(coleccion)} Pokémon) ===")

    if coleccion == [] do
      IO.puts("Tu colección está vacía.")
    else
      coleccion
      |> Enum.with_index(1)
      |> Enum.each(fn {pkm, i} ->
        especie    = pkm["especie"] || to_string(pkm.especie)
        tipos      = pkm["tipos"] || []
        tipos_str  = Enum.join(tipos, "/") |> String.capitalize()
        rareza     = pkm["rareza"] || to_string(pkm.rareza)
        id         = pkm["id"] || pkm.id
        ataque     = pkm["ataque"] || pkm.ataque
        defensa    = pkm["defensa"] || pkm.defensa
        velocidad  = pkm["velocidad"] || pkm.velocidad
        dueno      = pkm["dueño_original"] || pkm.dueño_original
        movs       = pkm["movimientos"] || pkm.movimientos || []

        movs_str = movs
                   |> Enum.map(fn m -> "#{m["nombre"]}(#{m["poder_base"]})" end)
                   |> Enum.join(", ")

        IO.puts("\n  #{i}. [##{id}] #{String.capitalize(especie)} (#{tipos_str}) [#{rareza}]")
        IO.puts("     Ataque: #{ataque} | Defensa: #{defensa} | Velocidad: #{velocidad} | Salud máx: 100")
        IO.puts("     Dueño original: #{dueno}")
        IO.puts("     Movimientos: #{movs_str}")
      end)
    end
  end

  @doc """
  Muestra clasificación global ordenada por victorias, desempate por monedas_acumuladas.
  """
  def clasificacion do
    entrenadores = cargar_todos()

    ranking = entrenadores
              |> Enum.sort_by(fn e ->
                {-e["victorias"], -e["monedas_acumuladas"]}
              end)

    IO.puts("\n=== Clasificación Global ===")
    IO.puts("#    Entrenador       Victorias   Monedas acumuladas")

    ranking
    |> Enum.with_index(1)
    |> Enum.each(fn {e, pos} ->
      IO.puts("#{pos}    #{String.pad_trailing(e["nombre"], 16)} #{String.pad_leading(to_string(e["victorias"]), 9)}   #{e["monedas_acumuladas"]}")
    end)
  end

  @doc """
  Suma monedas al entrenador y actualiza monedas_acumuladas.
  """
  def agregar_monedas(entrenador, cantidad) do
    %{entrenador |
      "monedas"            => entrenador["monedas"] + cantidad,
      "monedas_acumuladas" => entrenador["monedas_acumuladas"] + cantidad
    }
  end

  @doc """
  Suma una victoria al entrenador.
  """
  def agregar_victoria(entrenador) do
    %{entrenador | "victorias" => entrenador["victorias"] + 1}
  end

  @doc """
  Guarda o actualiza un entrenador en el archivo JSON.
  """
  def guardar_entrenador(datos_entrenador) do
    entrenadores = cargar_todos()

    nueva_lista = [datos_entrenador | Enum.reject(entrenadores, fn e ->
      e["nombre"] == datos_entrenador["nombre"]
    end)]

    case Jason.encode(nueva_lista, pretty: true) do
      {:ok, json_texto} -> File.write!(@archivo_entrenadores, json_texto)
      {:error, _}       -> IO.puts("Error al guardar entrenador.")
    end
  end
end

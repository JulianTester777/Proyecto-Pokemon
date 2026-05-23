defmodule PokemonBattle.GestorEntrenadores do
  alias PokemonBattle.{Entrenador, Persistencia}

  @archivo "data/trainers.json"

  def cargar_todos(archivo \\ @archivo) do
    Persistencia.cargar_datos(archivo)
    |> Enum.map(&map_a_struct/1)
  end

  def map_a_struct(m) do
    %Entrenador{
      nombre: m["nombre"],
      clave: m["clave"] || m[:clave],
      monedas: m["monedas"] || 0,
      monedas_acumuladas: m["monedas_acumuladas"] || 0,
      victorias: m["victorias"] || 0,
      coleccion: Enum.map(m["coleccion"] || [], &map_a_pokemon/1),
      sobres_pendientes: m["sobres_pendientes"] || [],
      equipos: Enum.map(m["equipos"] || [], &normalizar_equipo/1),
      equipo_actual: m["equipo_actual"] || m[:equipo_actual]
    }
  end

  def map_a_pokemon(m) do
    %PokemonBattle.Pokemon{
      id: m["id"],
      especie: m["especie"],
      rareza: parse_rareza(m["rareza"] || m[:rareza]),
      ataque: m["ataque"],
      defensa: m["defensa"],
      velocidad: m["velocidad"],
      dueño_original: m["dueño_original"] || m[:"dueño_original"],
      tipos: m["tipos"] || [],
      movimientos: Enum.map(m["movimientos"] || [], &map_a_movimiento/1),
      salud_actual: m["salud_actual"] || 100,
      salud_maxima: m["salud_maxima"] || 100
    }
  end

  defp map_a_movimiento(mov) do
    %PokemonBattle.Movimiento{
      nombre: mov["nombre"] || mov[:nombre],
      tipo: mov["tipo"] || mov[:tipo],
      poder_base: mov["poder_base"] || mov[:poder_base]
    }
  end

  defp normalizar_equipo(equipo) do
    %{
      "nombre" => equipo["nombre"] || equipo[:nombre],
      "pokemon_ids" => List.wrap(equipo["pokemon_ids"] || equipo[:pokemon_ids] || equipo["pokemons"] || equipo[:pokemons])
    }
  end

  defp parse_rareza(nil), do: :comun
  defp parse_rareza(rareza) when is_atom(rareza), do: rareza
  defp parse_rareza(rareza), do: String.to_atom(rareza)

  # -------- LOGIN --------

  def iniciar_sesion(nombre), do: iniciar_sesion(nombre, nil, @archivo)

  def iniciar_sesion(nombre, arg2) when is_binary(arg2) do
    if String.ends_with?(arg2, ".json") do
      iniciar_sesion(nombre, nil, arg2)
    else
      iniciar_sesion(nombre, arg2, @archivo)
    end
  end

  def iniciar_sesion(nombre, clave, archivo) do
    case buscar_entrenador(nombre, archivo) do
      nil ->
        nuevo = %Entrenador{
          nombre: nombre,
          clave: clave,
          monedas: 0,
          monedas_acumuladas: 0,
          victorias: 0,
          coleccion: [],
          sobres_pendientes: [%{"id" => generar_id(), "tipo" => "basico"}],
          equipos: [],
          equipo_actual: nil
        }

        :ok = guardar_entrenador(nuevo, archivo)
        IO.puts("Cuenta creada para #{nombre}")
        nuevo

      existente when is_nil(existente.clave) ->
        actualizado = %{existente | clave: clave}
        :ok = guardar_entrenador(actualizado, archivo)
        IO.puts("Bienvenido #{nombre}")
        actualizado

      existente when existente.clave == clave ->
        IO.puts("Bienvenido #{nombre}")
        existente

      _ ->
        {:error, "Clave incorrecta"}
    end
  end

  def buscar_entrenador(nombre, archivo \\ @archivo) do
    Enum.find(cargar_todos(archivo), &(&1.nombre == nombre))
  end

  # -------- PERFIL --------

  def perfil(entrenador) do
    IO.puts("\n=== Perfil de #{entrenador.nombre} ===")
    IO.puts("Monedas: #{entrenador.monedas}")
    IO.puts("Sobres pendientes: #{length(entrenador.sobres_pendientes)}")
    IO.puts("Pokémon en inventario: #{length(entrenador.coleccion)}")
  end

  def clasificacion(entrenadores) do
    entrenadores
    |> Enum.sort_by(fn e -> {-e.victorias, -e.monedas_acumuladas} end)
    |> Enum.with_index(1)
    |> Enum.map(fn {e, i} -> {i, e} end)
  end

  # -------- INVENTARIO --------

  def inventario(entrenador, especies) do
    especies_por_nombre =
      especies
      |> Enum.map(&{&1.especie, &1})
      |> Map.new()

    IO.puts("\n=== Inventario de #{entrenador.nombre} (#{length(entrenador.coleccion)} Pokémon) ===")

    Enum.each(entrenador.coleccion, fn p ->
      especie = Map.get(especies_por_nombre, p.especie)
      tipos = especie |> Map.get(:tipos, p.tipos || []) |> Enum.map_join("/", &String.capitalize/1)

      movs =
        p.movimientos
        |> Enum.map(fn m -> "#{m.nombre}(#{m.poder_base})" end)
        |> Enum.join(", ")

      IO.puts("""
      [##{p.id}] #{String.capitalize(p.especie)} (#{tipos}) [#{p.rareza}]
      Ataque: #{p.ataque} | Defensa: #{p.defensa} | Velocidad: #{p.velocidad} | Salud máx: #{p.salud_maxima}
      Dueño original: #{p.dueño_original}
      Movimientos: #{movs}
      """)
    end)
  end

  # -------- EQUIPOS --------

  def crear_equipo(entrenador, nombre, ids, archivo \\ @archivo) do
    ids = normalizar_ids(ids)

    cond do
      nombre == nil or nombre == "" ->
        {:error, "El nombre del equipo no puede estar vacío"}

      equipo_existe?(entrenador, nombre) ->
        {:error, "Ya existe un equipo llamado #{nombre}"}

      length(ids) < 1 or length(ids) > 3 ->
        {:error, "El equipo debe tener entre 1 y 3 Pokémon"}

      ids != Enum.uniq(ids) ->
        {:error, "No puede haber Pokémon duplicados en el equipo"}

      not ids_pertenecen?(entrenador, ids) ->
        {:error, "Uno o más Pokémon no pertenecen al inventario"}

      true ->
        equipo = %{"nombre" => nombre, "pokemon_ids" => ids}
        actualizado = %{entrenador | equipos: entrenador.equipos ++ [equipo]}
        :ok = guardar_entrenador(actualizado, archivo)
        {:ok, actualizado}
    end
  end

  def listar_equipos(entrenador) do
    if entrenador.equipos == [] do
      "Equipos guardados:\n(sin equipos)"
    else
      encabezado = "Equipos guardados:"

      cuerpo =
        Enum.map_join(entrenador.equipos, "\n", fn equipo ->
          pokemon_texto =
            equipo["pokemon_ids"]
            |> Enum.map(&pokemon_resumen(entrenador, &1))
            |> Enum.join(", ")

          "#{equipo["nombre"]}\n[#{length(equipo["pokemon_ids"] )}/3]: #{pokemon_texto}"
        end)

      encabezado <> "\n" <> cuerpo
    end
  end

  def agregar_pokemon_equipo(entrenador, nombre_equipo, id_pokemon, archivo \\ @archivo) do
    with {:ok, equipo} <- obtener_equipo(entrenador, nombre_equipo),
         false <- Enum.member?(equipo["pokemon_ids"], id_pokemon),
         true <- pokemon_pertenece?(entrenador, id_pokemon),
         true <- length(equipo["pokemon_ids"]) < 3 do
      nuevo_equipo = %{equipo | "pokemon_ids" => equipo["pokemon_ids"] ++ [id_pokemon]}
      actualizado = actualizar_equipo(entrenador, nombre_equipo, nuevo_equipo)
      :ok = guardar_entrenador(actualizado, archivo)
      {:ok, actualizado}
    else
      true -> {:error, "No se puede agregar el Pokémon al equipo"}
      false -> {:error, "No se puede agregar el Pokémon al equipo"}
      {:error, msg} -> {:error, msg}
    end
  end

  def quitar_pokemon_equipo(entrenador, nombre_equipo, id_pokemon, archivo \\ @archivo) do
    with {:ok, equipo} <- obtener_equipo(entrenador, nombre_equipo),
         false <- equipo_actual_cargado?(entrenador, nombre_equipo),
         true <- Enum.member?(equipo["pokemon_ids"], id_pokemon),
         true <- length(equipo["pokemon_ids"]) > 1 do
      nuevos_ids = Enum.reject(equipo["pokemon_ids"], &(&1 == id_pokemon))
      nuevo_equipo = %{equipo | "pokemon_ids" => nuevos_ids}
      actualizado = actualizar_equipo(entrenador, nombre_equipo, nuevo_equipo)
      :ok = guardar_entrenador(actualizado, archivo)
      {:ok, actualizado}
    else
      false -> {:error, "No se puede quitar ese Pokémon del equipo"}
      true -> {:error, "No se puede quitar ese Pokémon del equipo"}
      {:error, msg} -> {:error, msg}
    end
  end

  def usar_equipo(entrenador, nombre_equipo, archivo \\ @archivo) do
    with {:ok, equipo} <- obtener_equipo(entrenador, nombre_equipo),
         :ok <- validar_equipo_en_inventario(entrenador, equipo) do
      actualizado = %{entrenador | equipo_actual: nombre_equipo}
      :ok = guardar_entrenador(actualizado, archivo)
      {:ok, actualizado}
    end
  end

  def equipo_para_batalla(entrenador) do
    case equipo_seleccionado(entrenador) do
      {:ok, ids} ->
        pokemon = Enum.filter(entrenador.coleccion, &(&1.id in ids))
        {:ok, %{entrenador | coleccion: pokemon}}

      {:error, _} ->
        case entrenador.coleccion do
          [] -> {:error, "El entrenador #{entrenador.nombre} no tiene un Pokémon usable para la batalla"}
          _ -> {:error, "Debes usar un equipo guardado antes de iniciar la batalla"}
        end
    end
  end

  def buscar_pokemon(entrenador, id_pokemon) do
    Enum.find(entrenador.coleccion, &(&1.id == id_pokemon))
  end

  def pokemon_pertenece?(entrenador, id_pokemon) do
    not is_nil(buscar_pokemon(entrenador, id_pokemon))
  end

  # -------- GUARDAR --------

  def guardar_entrenador(e, archivo \\ @archivo) do
    mapa = entrenador_a_map(e)
    mapa = limpiar_equipo_si_necesario(mapa)

    case Persistencia.actualizar_datos(archivo, fn lista ->
          [mapa | Enum.reject(lista, &(&1["nombre"] == e.nombre))]
        end) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
      other -> other
    end
  end

  def pokemon_a_map(p) do
    %{
      "id" => p.id,
      "especie" => p.especie,
      "rareza" => to_string(p.rareza),
      "ataque" => p.ataque,
      "defensa" => p.defensa,
      "velocidad" => p.velocidad,
      "salud_actual" => p.salud_actual,
      "salud_maxima" => p.salud_maxima,
      "movimientos" => Enum.map(p.movimientos || [], &Map.from_struct/1),
      "dueño_original" => p.dueño_original,
      "tipos" => p.tipos || []
    }
  end

  # -------- INTERCAMBIO --------

  def intercambiar(nombre1, id1, nombre2, id2, archivo \\ @archivo) do
    Persistencia.actualizar_datos(archivo, fn lista ->
      case encontrar_entrenadores_y_pokemon(lista, nombre1, id1, nombre2, id2) do
        {:ok, e1, p1, e2, p2} ->
          nuevo_e1 = %{e1 | "coleccion" => reemplazar_pokemon(e1["coleccion"], p1, p2)}
          nuevo_e2 = %{e2 | "coleccion" => reemplazar_pokemon(e2["coleccion"], p2, p1)}

          nuevos =
            lista
            |> reemplazar_entrenador(nuevo_e1)
            |> reemplazar_entrenador(nuevo_e2)

          {:ok, nuevos}

        {:error, reason} ->
          {:error, reason}
      end
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      _ -> {:ok, "Intercambio realizado"}
    end
  end

  # -------- HELPERS --------

  defp entrenador_a_map(e) do
    %{
      "nombre" => e.nombre,
      "clave" => e.clave,
      "monedas" => e.monedas,
      "monedas_acumuladas" => e.monedas_acumuladas,
      "victorias" => e.victorias,
      "coleccion" => Enum.map(e.coleccion, &pokemon_a_map/1),
      "sobres_pendientes" => e.sobres_pendientes,
      "equipos" => e.equipos,
      "equipo_actual" => e.equipo_actual
    }
  end

   defp limpiar_equipo_si_necesario(entrenador_map) do
    case entrenador_map["equipo_actual"] do
      nil ->
        entrenador_map

      nombre_equipo ->
        equipo = Enum.find(entrenador_map["equipos"] || [], &(&1["nombre"] == nombre_equipo))
        ids_equipo = if equipo, do: equipo["pokemon_ids"], else: []
        ids_coleccion = Enum.map(entrenador_map["coleccion"] || [], & &1["id"])
        faltantes = Enum.reject(ids_equipo, &(&1 in ids_coleccion))

        if faltantes != [] do
          IO.puts("⚠️  El equipo '#{nombre_equipo}' ya no es válido porque un Pokémon fue intercambiado. Selecciona un nuevo equipo con 'usar_equipo'.")
          %{entrenador_map | "equipo_actual" => nil}
        else
          entrenador_map
        end
    end
  end

  defp equipo_existe?(entrenador, nombre) do
    Enum.any?(entrenador.equipos, &(&1["nombre"] == nombre))
  end

  defp obtener_equipo(entrenador, nombre) do
    case Enum.find(entrenador.equipos, &(&1["nombre"] == nombre)) do
      nil -> {:error, "No existe el equipo #{nombre}"}
      equipo -> {:ok, equipo}
    end
  end

  defp actualizar_equipo(entrenador, nombre, nuevo_equipo) do
    equipos =
      Enum.map(entrenador.equipos, fn equipo ->
        if equipo["nombre"] == nombre, do: nuevo_equipo, else: equipo
      end)

    %{entrenador | equipos: equipos}
  end

  defp normalizar_ids(ids) when is_binary(ids) do
    ids
    |> String.split([",", " "], trim: true)
    |> Enum.map(&String.to_integer/1)
  end

  defp normalizar_ids(ids) when is_list(ids), do: Enum.map(ids, &to_integer/1)
  defp normalizar_ids(id), do: [to_integer(id)]

  defp to_integer(id) when is_integer(id), do: id
  defp to_integer(id) when is_binary(id), do: String.to_integer(id)

  defp ids_pertenecen?(entrenador, ids) do
    inventario = MapSet.new(Enum.map(entrenador.coleccion, & &1.id))
    Enum.all?(ids, &MapSet.member?(inventario, &1))
  end

  defp equipo_actual_cargado?(entrenador, nombre_equipo) do
    entrenador.equipo_actual == nombre_equipo
  end

  defp validar_equipo_en_inventario(entrenador, equipo) do
    ids = equipo["pokemon_ids"]
    inventario = MapSet.new(Enum.map(entrenador.coleccion, & &1.id))

    faltantes = Enum.reject(ids, &MapSet.member?(inventario, &1))

    if faltantes == [] do
      :ok
    else
      {:error, "Faltan Pokémon en el inventario: #{Enum.join(Enum.map(faltantes, &to_string/1), ", ")}"}
    end
  end

  defp equipo_seleccionado(entrenador) do
    case entrenador.equipo_actual do
      nil -> {:error, "No hay equipo seleccionado"}
      nombre ->
        with {:ok, equipo} <- obtener_equipo(entrenador, nombre),
             :ok <- validar_equipo_en_inventario(entrenador, equipo) do
          {:ok, equipo["pokemon_ids"]}
        end
    end
  end

  defp pokemon_resumen(entrenador, id) do
    case buscar_pokemon(entrenador, id) do
      nil -> "[#" <> to_string(id) <> "] (faltante)"
      p -> "[#" <> to_string(p.id) <> "] " <> String.capitalize(p.especie)
    end
  end

  defp generar_id do
    System.unique_integer([:positive, :monotonic])
  end

  defp reemplazar_pokemon(lista, salido, entrante) do
    lista
    |> Enum.reject(&(&1["id"] == salido["id"]))
    |> Kernel.++([pokemon_a_map(map_a_pokemon(entrante))])
  end

  defp reemplazar_entrenador(lista, entrenador_map) do
    [entrenador_map | Enum.reject(lista, &(&1["nombre"] == entrenador_map["nombre"]))]
  end

  defp encontrar_entrenadores_y_pokemon(lista, nombre1, id1, nombre2, id2) do
    e1 = Enum.find(lista, &(&1["nombre"] == nombre1))
    e2 = Enum.find(lista, &(&1["nombre"] == nombre2))

    cond do
      is_nil(e1) or is_nil(e2) ->
        {:error, "Entrenador no encontrado"}

      nombre1 == nombre2 ->
        {:error, "No se permiten intercambios consigo mismo"}

      true ->
        p1 = Enum.find(e1["coleccion"] || [], &(&1["id"] == id1))
        p2 = Enum.find(e2["coleccion"] || [], &(&1["id"] == id2))

        cond do
          is_nil(p1) -> {:error, "Pokémon #{id1} no existe en #{nombre1}"}
          is_nil(p2) -> {:error, "Pokémon #{id2} no existe en #{nombre2}"}
          true -> {:ok, e1, p1, e2, p2}
        end
    end
  end
end

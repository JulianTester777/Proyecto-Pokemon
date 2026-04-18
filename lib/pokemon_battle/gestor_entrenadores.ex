defmodule PokemonBattle.GestorEntrenadores do
  alias PokemonBattle.Persistencia

  @archivo_entrenadores "data/trainers.json"

  # Estructura del Entrenador
  defstruct [:nombre, :monedas, :coleccion]

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

    # Buscamos si el nombre ya existe en la lista
    entrenador_existente = Enum.find(entrenadores, fn e -> e["nombre"] == nombre end)

    if entrenador_existente do
      IO.puts("¡Bienvenido de nuevo, #{nombre}!")
      entrenador_existente
    else
      IO.puts("Creando perfil nuevo para #{nombre}...")
      nuevo = %{
        "nombre" => nombre,
        "monedas" => 500,
        "coleccion" => []
      }
      guardar_entrenador(nuevo)
      nuevo
    end
  end

  @doc """
  Guarda o actualiza un entrenador en el archivo JSON.
  """
  def guardar_entrenador(datos_entrenador) do
    entrenadores = cargar_todos()

    # Actualizamos la lista: quitamos la versión vieja y ponemos la nueva
    nueva_lista = [datos_entrenador | Enum.reject(entrenadores, fn e -> e["nombre"] == datos_entrenador["nombre"] end)]

    # Usamos Jason para convertir a texto y guardar (necesitas implementar esto en Persistencia)
    case Jason.encode(nueva_lista, pretty: true) do
      {:ok, json_texto} -> File.write!(@archivo_entrenadores, json_texto)
      {:error, _} -> IO.puts("Error al codificar datos del entrenador.")
    end
  end
end

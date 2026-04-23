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
      monedas: m["monedas"],
      monedas_acumuladas: m["monedas_acumuladas"],
      victorias: m["victorias"],
      coleccion: m["coleccion"],
      sobres_pendientes: m["sobres_pendientes"],
      equipos: m["equipos"] || []
    }
  end

  def iniciar_sesion(nombre) do
    case Enum.find(cargar_todos(), &(&1.nombre == nombre)) do
      nil ->
        nuevo = %Entrenador{
          nombre: nombre,
          sobres_pendientes: [%{"id" => :rand.uniform(100_000), "tipo" => "basico"}]
        }

        guardar_entrenador(nuevo)
        nuevo

      e ->
        e
    end
  end

  def guardar_entrenador(e) do
    lista = cargar_todos()

    nueva =
      [e | Enum.reject(lista, &(&1.nombre == e.nombre))]
      |> Enum.map(&Map.from_struct/1)

    Persistencia.guardar_datos(@archivo, nueva)
  end
end

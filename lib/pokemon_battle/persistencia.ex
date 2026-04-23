defmodule PokemonBattle.Persistencia do
  def cargar_datos(ruta) do
    case File.read(ruta) do
      {:ok, contenido} ->
        case Jason.decode(contenido) do
          {:ok, data} -> data
          _ -> []
        end

      _ -> []
    end
  end

  def guardar_datos(ruta, data) do
    case Jason.encode(data, pretty: true) do
      {:ok, json} -> File.write!(ruta, json)
      _ -> :error
    end
  end
end

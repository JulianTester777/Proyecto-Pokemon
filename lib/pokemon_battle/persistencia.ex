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

  def cargar_especies(ruta) do
    cargar_datos(ruta)
    |> Enum.map(fn e ->
      %PokemonBattle.Especie{
        especie: e["especie"],
        tipos: e["tipos"],
        ataque_base: e["ataque_base"],
        defensa_base: e["defensa_base"],
        velocidad_base: e["velocidad_base"]
      }
    end)
  end


end

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
    transaccionar(ruta, fn -> escribir_json(ruta, data) end)
  end

  def actualizar_datos(ruta, fun) when is_function(fun, 1) do
    transaccionar(ruta, fn ->
      current = cargar_datos(ruta)
      nuevo = fun.(current)

      case nuevo do
        {:error, _} = error -> error
        {:ok, datos} when is_list(datos) or is_map(datos) -> escribir_json(ruta, datos)
        datos when is_list(datos) or is_map(datos) -> escribir_json(ruta, datos)
        other -> other
      end
    end)
  end

  def append_line(ruta, line) do
    transaccionar(ruta, fn -> File.write(ruta, line, [:append]) end)
  end

  def cargar_especies(ruta) do
    cargar_datos(ruta)
    |> Enum.map(fn e ->
      %PokemonBattle.Especie{
        especie: e["especie"],
        tipos: e["tipos"] || [],
        ataque_base: e["ataque_base"],
        defensa_base: e["defensa_base"],
        velocidad_base: e["velocidad_base"]
      }
    end)
  end

  def especies_por_nombre(ruta \\ "data/pokemon.json") do
    cargar_especies(ruta)
    |> Map.new(fn especie -> {especie.especie, especie} end)
  end

  defp transaccionar(ruta, fun) do
    lock = {__MODULE__, Path.expand(ruta)}

    :global.trans(lock, fn ->
      case fun.() do
        :ok -> :ok
        {:ok, datos} when is_list(datos) or is_map(datos) -> escribir_json(ruta, datos)
        datos when is_list(datos) or is_map(datos) -> escribir_json(ruta, datos)
        {:error, _} = error -> error
        other -> other
      end
    end)
  end

  defp escribir_json(ruta, data) do
    with {:ok, json} <- Jason.encode(data, pretty: true) do
      tmp = ruta <> ".tmp-" <> Integer.to_string(System.unique_integer([:positive, :monotonic]))
      :ok = File.write(tmp, json)
      File.rename!(tmp, ruta)
      :ok
    end
  end
end

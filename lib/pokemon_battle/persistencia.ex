defmodule PokemonBattle.Persistencia do
  def cargar_datos(ruta) do
    if File.exists?(ruta) do
      File.read!(ruta) |> Jason.decode!()
    else
      {:error, "Archivo no encontrado"}
    end
  end
end

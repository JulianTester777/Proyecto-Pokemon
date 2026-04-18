defmodule PokemonBattle.Servidor do
  alias PokemonBattle.{GestorEntrenadores, Persistencia, SistemaSobres}

  def iniciar do
    # 1. Cargamos datos base del juego
    pokes_base = Persistencia.cargar_datos("data/pokemon.json")
    movs_base = Persistencia.cargar_datos("data/moves.json")

    IO.puts("==================================")
    IO.puts("   BIENVENIDO A POKÉMON BATTLE    ")
    IO.puts("==================================")

    nombre = IO.gets("Ingresa tu nombre de entrenador: ") |> String.trim()

    # 2. Iniciamos sesión (Carga o crea el perfil en el JSON)
    entrenador = GestorEntrenadores.iniciar_sesion(nombre)

    bucle_principal(entrenador, pokes_base, movs_base)
  end

  defp bucle_principal(entrenador, pokes, movs) do
    IO.puts("\n--- ESTADO DE #{entrenador["nombre"]} ---")
    IO.puts("Monedas: #{entrenador["monedas"]} | Pokémon: #{length(entrenador["coleccion"])}")
    IO.puts("1. Abrir Sobre (150 monedas)")
    IO.puts("2. Ver Colección Detallada")
    IO.puts("3. Guardar y Salir")

    opcion = IO.gets("\nSelecciona una opción: ") |> String.trim()

    case opcion do
      "1" ->
        # Lógica de compra
        if entrenador["monedas"] >= 150 do
          nuevos = SistemaSobres.abrir_sobre(entrenador["nombre"], pokes, movs)

          # Actualizamos el mapa del entrenador
          entrenador_actualizado = %{entrenador |
            "monedas" => entrenador["monedas"] - 150,
            "coleccion" => entrenador["coleccion"] ++ nuevos
          }

          # GUARDADO AUTOMÁTICO en el JSON
          GestorEntrenadores.guardar_entrenador(entrenador_actualizado)

          IO.puts("¡Sobre abierto con éxito!")
          bucle_principal(entrenador_actualizado, pokes, movs)
        else
          IO.puts("¡No tienes suficientes monedas!")
          bucle_principal(entrenador, pokes, movs)
        end

      "2" ->
        IO.puts("\n--- TU EQUIPO ---")
        if entrenador["coleccion"] == [], do: IO.puts("Tu colección está vacía.")

        Enum.each(entrenador["coleccion"], fn p ->
          # Ajustamos según cómo se guardan en tu struct/mapa
          IO.puts("- #{String.capitalize(p.especie || p["especie"])} | Atk: #{p.ataque || p["ataque"]}")
        end)
        bucle_principal(entrenador, pokes, movs)

      "3" ->
        IO.puts("¡Partida guardada! Adiós, #{entrenador["nombre"]}.")

      _ ->
        IO.puts("Opción inválida.")
        bucle_principal(entrenador, pokes, movs)
    end
  end
end

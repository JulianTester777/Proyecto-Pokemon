defmodule PokemonBattle.GestorSalas do
  alias PokemonBattle.{SupervisorBatallas, Intercambio}

  # Generador simple de códigos tipo IC-123
  defp generar_codigo do
    "IC-" <> Integer.to_string(:rand.uniform(999))
  end

  # -------- CREAR SALA --------

  def crear_sala_intercambio(usuario) do
    codigo = generar_codigo()

    case SupervisorBatallas.crear_intercambio(codigo, usuario) do
      {:ok, _pid} ->
        {:ok, codigo}

      {:error, _} ->
        {:error, "No se pudo crear la sala"}
    end
  end

  # -------- UNIRSE --------

  def unirse_sala_intercambio(codigo, usuario) do
    case Intercambio.unirse(codigo, usuario) do
      {:ok, msg} -> {:ok, msg}
      {:error, msg} -> {:error, msg}
    end
  end

  # -------- OFRECER --------

  def ofrecer_pokemon(codigo, usuario, pokemon_id) do
    Intercambio.ofrecer(codigo, usuario, pokemon_id)
  end

  # -------- CONFIRMAR --------

  def confirmar_intercambio(codigo, usuario) do
    Intercambio.confirmar(codigo, usuario)
  end

  # -------- CANCELAR --------

  def cancelar_intercambio(codigo, usuario) do
    Intercambio.cancelar(codigo, usuario)
    {:ok, "Intercambio cancelado"}
  end
end

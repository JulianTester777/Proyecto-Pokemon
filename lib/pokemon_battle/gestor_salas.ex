defmodule PokemonBattle.GestorSalas do
  alias PokemonBattle.{Cluster, Intercambio, SupervisorBatallas}

  def crear_sala_intercambio(usuario) do
    cond do
      Cluster.sala_intercambio_activa?(usuario) ->
        {:error, "Ya tienes una sala activa"}

      true ->
        codigo = generar_codigo()

        case SupervisorBatallas.crear_intercambio(codigo, usuario) do
          {:ok, pid} ->
            with :ok <- Cluster.registrar_sala_intercambio(codigo, Node.self()),
                 :ok <- Cluster.registrar_miembro_intercambio(usuario, codigo) do
              {:ok, codigo}
            else
              {:error, msg} ->
                rollback_intercambio_creado(pid, codigo, usuario)
                {:error, msg}
            end

          {:error, {:already_started, _pid}} ->
            crear_sala_intercambio(usuario)

          {:error, _} = error ->
            error
        end
    end
  end

  def unirse_sala_intercambio(codigo, usuario) do
    cond do
      Cluster.sala_intercambio_activa?(usuario) ->
        {:error, "Ya tienes una sala activa"}

      true ->
        Intercambio.unirse(codigo, usuario)
    end
  end

  def ofrecer_pokemon(codigo, usuario, pokemon_id) do
    Intercambio.ofrecer(codigo, usuario, pokemon_id)
  end

  def confirmar_intercambio(codigo, usuario) do
    Intercambio.confirmar(codigo, usuario)
  end

  def cancelar_intercambio(codigo, usuario) do
    Intercambio.cancelar(codigo, usuario)
  end

  def sala_activa?(usuario) do
    Cluster.sala_intercambio_activa?(usuario)
  end

  def codigo_de_sala(usuario) do
    Cluster.codigo_de_sala_intercambio(usuario)
  end

  def registrar_sala(usuario, codigo) do
    Cluster.registrar_miembro_intercambio(usuario, codigo)
  end

  def liberar_sala(usuario) do
    Cluster.liberar_miembro_intercambio(usuario)
  end

  def salas_activas do
    Cluster.codigos_sala_intercambio()
    |> Enum.filter(&String.starts_with?(&1, "IC-"))
  end

  defp rollback_intercambio_creado(pid, codigo, usuario) do
    _ = Cluster.liberar_sala_intercambio(codigo)
    _ = Cluster.liberar_miembro_intercambio(usuario)
    _ = DynamicSupervisor.terminate_child(PokemonBattle.SupervisorBatallas, pid)
    {:error, "No se pudo registrar la sala de intercambio"}
  end

  defp generar_codigo do
    node_tag = Node.self() |> Atom.to_string() |> Base.url_encode64(padding: false)
    "IC-" <> node_tag <> "-" <> Integer.to_string(:erlang.unique_integer([:positive, :monotonic]))
  end
end

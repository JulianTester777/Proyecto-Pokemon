defmodule PokemonBattle.Intercambio do
  use GenServer

  def start_link({codigo, creador}) do
    GenServer.start_link(__MODULE__, {codigo, creador}, name: via(codigo))
  end

  def unirse(codigo, usuario) do
    GenServer.call(via(codigo), {:unirse, usuario})
  end

  def ofrecer(codigo, usuario, pokemon_id) do
    GenServer.call(via(codigo), {:ofrecer, usuario, pokemon_id})
  end

  def confirmar(codigo, usuario) do
    GenServer.call(via(codigo), {:confirmar, usuario})
  end

  def cancelar(codigo, usuario) do
    GenServer.cast(via(codigo), {:cancelar, usuario})
  end

  # =========================
  # REGISTRY
  # =========================

  defp via(codigo) do
    {:via, Registry, {PokemonBattle.Registry, codigo}}
  end

  # =========================
  # INIT
  # =========================

  def init({codigo, creador}) do
    estado = %{
      codigo: codigo,
      jugador1: creador,
      jugador2: nil,
      ofertas: %{},           # %{usuario => pokemon_id}
      confirmados: MapSet.new()
    }

    {:ok, estado}
  end

  # =========================
  # HANDLE CALL
  # =========================

  # Unirse a sala
  def handle_call({:unirse, usuario}, _from, estado) do
    cond do
      estado.jugador2 != nil ->
        {:reply, {:error, "La sala ya está llena"}, estado}

      usuario == estado.jugador1 ->
        {:reply, {:error, "No puedes unirte a tu propia sala"}, estado}

      true ->
        nuevo_estado = %{estado | jugador2: usuario}
        {:reply, {:ok, "Te uniste a la sala #{estado.codigo}"}, nuevo_estado}
    end
  end

  # Ofrecer Pokémon
  def handle_call({:ofrecer, usuario, pokemon_id}, _from, estado) do
    if usuario not in [estado.jugador1, estado.jugador2] do
      {:reply, {:error, "No estás en esta sala"}, estado}
    else
      nuevas_ofertas = Map.put(estado.ofertas, usuario, pokemon_id)

      nuevo_estado = %{
        estado
        | ofertas: nuevas_ofertas,
          confirmados: MapSet.new() # reset si cambia oferta
      }

      {:reply, {:ok, "Oferta registrada"}, nuevo_estado}
    end
  end

  # Confirmar intercambio
  def handle_call({:confirmar, usuario}, _from, estado) do
    if usuario not in [estado.jugador1, estado.jugador2] do
      {:reply, {:error, "No estás en esta sala"}, estado}
    else
      nuevos_confirmados = MapSet.put(estado.confirmados, usuario)
      nuevo_estado = %{estado | confirmados: nuevos_confirmados}

      if intercambio_listo?(nuevo_estado) do
        ejecutar_intercambio(nuevo_estado)

        {:stop, :normal,
         {:ok, "Intercambio completado correctamente"},
         nuevo_estado}
      else
        {:reply, {:ok, "Confirmación registrada"}, nuevo_estado}
      end
    end
  end

  # =========================
  # HANDLE CAST
  # =========================

  def handle_cast({:cancelar, _usuario}, estado) do
    {:stop, :normal, estado}
  end

  # =========================
  # LÓGICA INTERNA
  # =========================

  defp intercambio_listo?(estado) do
    estado.jugador1 != nil and
      estado.jugador2 != nil and
      map_size(estado.ofertas) == 2 and
      MapSet.size(estado.confirmados) == 2
  end

  defp ejecutar_intercambio(estado) do
    j1 = estado.jugador1
    j2 = estado.jugador2

    p1 = estado.ofertas[j1]
    p2 = estado.ofertas[j2]

    PokemonBattle.GestorEntrenadores.intercambiar(j1, p1, j2, p2)
  end
end

defmodule PokemonBattle.ClusterTest do
  use ExUnit.Case, async: false

  alias PokemonBattle.{Cluster, GestorSalas, SupervisorBatallas}

  test "local battle node registry stores and clears codes" do
    codigo = "B-#{System.unique_integer([:positive])}"

    on_exit(fn ->
      Cluster.liberar_batalla_en_nodo(codigo)
    end)

    assert :ok = Cluster.registrar_batalla_en_nodo(codigo, Node.self())
    assert Cluster.nodo_de_batalla_en_nodo(codigo) == Node.self()
    assert codigo in Cluster.codigos_batalla_en_nodo()
    assert Cluster.nodo_de_batalla(codigo) == Node.self()

    assert :ok = Cluster.liberar_batalla_en_nodo(codigo)
    assert Cluster.nodo_de_batalla_en_nodo(codigo) == nil
  end

  test "battle activeness is false for unknown codes" do
    refute Cluster.batalla_activa?("B-missing-#{System.unique_integer([:positive])}")
  end

  test "active battle listing ignores exchange rooms" do
    {:ok, codigo} = GestorSalas.crear_sala_intercambio("tester")

    on_exit(fn ->
      GestorSalas.cancelar_intercambio(codigo, "tester")
    end)

    assert Enum.all?(SupervisorBatallas.salas_activas(), &String.starts_with?(&1, "B-"))
    refute codigo in SupervisorBatallas.salas_activas()
  end
end

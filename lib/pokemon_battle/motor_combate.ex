defmodule PokemonBattle.MotorCombate do
  @moduledoc """
  Lógica de cálculo de daño, efectividad de tipos y STAB.
  """

  # Tabla de efectividad: {tipo_movimiento, tipo_defensor} => modificador
  @efectividad %{
    {"fuego",     "planta"}    => 2.0,
    {"fuego",     "hielo"}     => 2.0,
    {"fuego",     "bicho"}     => 2.0,
    {"agua",      "fuego"}     => 2.0,
    {"agua",      "roca"}      => 2.0,
    {"agua",      "tierra"}    => 2.0,
    {"planta",    "agua"}      => 2.0,
    {"planta",    "roca"}      => 2.0,
    {"planta",    "tierra"}    => 2.0,
    {"electrico", "agua"}      => 2.0,
    {"electrico", "volador"}   => 2.0,
    {"roca",      "fuego"}     => 2.0,
    {"roca",      "hielo"}     => 2.0,
    {"roca",      "volador"}   => 2.0,
    {"roca",      "bicho"}     => 2.0,
    # Debilidades inversas (x0.5)
    {"planta",    "fuego"}     => 0.5,
    {"hielo",     "fuego"}     => 0.5,
    {"bicho",     "fuego"}     => 0.5,
    {"fuego",     "agua"}      => 0.5,
    {"roca",      "agua"}      => 0.5,
    {"tierra",    "agua"}      => 0.5,
    {"agua",      "planta"}    => 0.5,
    {"roca",      "planta"}    => 0.5,
    {"tierra",    "planta"}    => 0.5,
    {"agua",      "electrico"} => 0.5,
    {"volador",   "electrico"} => 0.5,
    {"fuego",     "roca"}      => 0.5,
    {"hielo",     "roca"}      => 0.5,
    {"volador",   "roca"}      => 0.5,
    {"bicho",     "roca"}      => 0.5
  }

  @doc """
  Calcula el daño de un movimiento sobre un defensor.
  Recibe la especie del atacante para calcular STAB.
  """
  def calcular_danio(atacante, movimiento, tipos_defensor, tipos_atacante) do
    poder     = movimiento["poder_base"]
    tipo_mov  = movimiento["tipo"]

    modificador_tipo = calcular_modificador_tipo(tipo_mov, tipos_defensor)
    stab             = calcular_stab(tipo_mov, tipos_atacante)

    round(atacante.ataque * poder * modificador_tipo * stab / 100)
  end

  @doc """
  Calcula el modificador de efectividad de tipo.
  Si el defensor tiene 2 tipos, multiplica ambos modificadores.
  """
  def calcular_modificador_tipo(tipo_movimiento, tipos_defensor) do
    Enum.reduce(tipos_defensor, 1.0, fn tipo_def, acc ->
      modificador = Map.get(@efectividad, {tipo_movimiento, tipo_def}, 1.0)
      acc * modificador
    end)
  end

  @doc """
  STAB: x1.5 si el tipo del movimiento coincide con algún tipo del atacante.
  """
  def calcular_stab(tipo_movimiento, tipos_atacante) do
    if tipo_movimiento in tipos_atacante, do: 1.5, else: 1.0
  end

  @doc """
  Describe con texto la efectividad para mostrar en pantalla.
  """
  def describir_efectividad(modificador) do
    cond do
      modificador >= 4.0 -> "¡Es muy efectivo!!"
      modificador >= 2.0 -> "¡Es muy efectivo!"
      modificador == 1.0 -> ""
      modificador <= 0.25 -> "No es muy efectivo..."
      modificador < 1.0  -> "No es muy efectivo..."
      true -> ""
    end
  end
end

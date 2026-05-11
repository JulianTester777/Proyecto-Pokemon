defmodule PokemonBattle.UI do

  def rojo(texto),     do: "\e[31m#{texto}\e[0m"
  def verde(texto),    do: "\e[32m#{texto}\e[0m"
  def amarillo(texto), do: "\e[33m#{texto}\e[0m"
  def azul(texto),     do: "\e[34m#{texto}\e[0m"
  def magenta(texto),  do: "\e[35m#{texto}\e[0m"
  def cian(texto),     do: "\e[36m#{texto}\e[0m"
  def negrita(texto),  do: "\e[1m#{texto}\e[0m"

  def color_tipo("Fuego"),     do: rojo("Fuego")
  def color_tipo("Agua"),      do: azul("Agua")
  def color_tipo("Planta"),    do: verde("Planta")
  def color_tipo("Eléctrico"), do: amarillo("Eléctrico")
  def color_tipo("Roca"),      do: "\e[90mRoca\e[0m"
  def color_tipo("Tierra"),    do: amarillo("Tierra")
  def color_tipo("Volador"),   do: cian("Volador")
  def color_tipo("Bicho"),     do: "\e[92mBicho\e[0m"
  def color_tipo("Normal"),    do: "Normal"
  def color_tipo(otro),        do: otro

  def color_rareza(:comun),  do: "común"
  def color_rareza(:raro),   do: azul("raro")
  def color_rareza(:epico),  do: magenta("épico")
  def color_rareza(otro),    do: to_string(otro)

  def barra_salud(salud, max \\ 100) do
    porcentaje = salud / max
    llenos = round(porcentaje * 20)
    vacios = 20 - llenos
    barra = String.duplicate("█", llenos) <> String.duplicate("░", vacios)

    color = cond do
      porcentaje > 0.5  -> "\e[32m#{barra}\e[0m"
      porcentaje > 0.25 -> "\e[33m#{barra}\e[0m"
      true              -> "\e[31m#{barra}\e[0m"
    end

    "#{color} #{salud}/#{max}"
  end

  def separador(char \\ "═", largo \\ 45) do
    IO.puts(String.duplicate(char, largo))
  end

  def titulo(texto) do
    largo = String.length(texto) + 4
    borde = String.duplicate("═", largo)
    IO.puts(negrita("╔#{borde}╗"))
    IO.puts(negrita("║  #{texto}  ║"))
    IO.puts(negrita("╚#{borde}╝"))
  end

  def exito(msg),  do: IO.puts(verde("✅ #{msg}"))
  def error(msg),  do: IO.puts(rojo("❌ #{msg}"))
  def info(msg),   do: IO.puts(azul("ℹ️  #{msg}"))
  def alerta(msg), do: IO.puts(amarillo("⚠️  #{msg}"))

  def mostrar_turno_batalla(turno, jugadores) do
    IO.puts("\n" <> negrita(amarillo("══════════ Turno #{turno} ══════════")))
    Enum.each(jugadores, fn {usuario, j} ->
      p = j.activo
      salud = p.salud_actual
      tipos = Enum.map_join(p.tipos || [], "/", &color_tipo/1)

      IO.puts(negrita("#{usuario}") <> " → " <>
              negrita(p.especie) <>
              " [#{tipos}] [#{color_rareza(p.rareza)}]")
      IO.puts("  Salud: #{barra_salud(salud)}")

      movs = Enum.map_join(p.movimientos, "  ", fn m ->
        "#{cian(m.nombre)}(#{m.poder_base})"
      end)
      IO.puts("  Movimientos: #{movs}")
    end)
    separador()
  end

  def mostrar_ataque(atacante, movimiento, danio, defensor, salud_restante) do
    IO.puts(
      "\n💥 " <>
      negrita(amarillo(atacante)) <>
      " usa " <> negrita(cian(movimiento)) <>
      " → " <> rojo("#{danio} daño") <>
      " a " <> negrita(amarillo(defensor)) <>
      "  Salud: #{barra_salud(salud_restante)}"
    )
  end

  def mostrar_ganador(nombre) do
    IO.puts("\n" <> negrita(amarillo("🏆 ══════════════════════════════ 🏆")))
    IO.puts(negrita(verde("       ¡#{nombre} gana la batalla!")))
    IO.puts(negrita(amarillo("🏆 ══════════════════════════════ 🏆\n")))
  end

end

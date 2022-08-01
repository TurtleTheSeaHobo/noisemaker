defmodule Noisemaker.Controller do
  require Logger

  def select(n), do: Logger.info("select #{n}")
  def volume_up, do: Logger.info("volume up")
  def volume_down, do: Logger.info("volume down")
end

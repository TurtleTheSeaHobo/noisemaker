defmodule Noisemaker.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Noisemaker.Driver,
      Noisemaker.Player,
      Noisemaker.FTP,
      Noisemaker.Controller,
    ]
    opts = [strategy: :one_for_one, name: Noisemaker.Supervisor]

    Supervisor.start_link(children, opts)
  end
end

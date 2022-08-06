defmodule Noisemaker.Player do
  use GenServer

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500,
    }
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def play(path, vol, cb \\ nil) do
    GenServer.cast(__MODULE__, {:play, path, vol, cb})
  end

  @impl true
  def init(_opts) do
    {:ok, :idle}
  end

  @impl true
  def handle_cast({:play, path, vol, cb}, state) do
    case state do
      {:playing, port, _cb} -> 
        {:os_pid, os_pid} = Port.info(port, :os_pid)
        Port.close(port)
        System.cmd("kill", ["#{os_pid}"]) 
      :idle -> nil
    end

    vol = Float.round(vol / 100, 3)
    port = Port.open(
      {:spawn, "ffmpeg -hide_banner -loglevel error -i #{path} -filter:a \"volume=#{vol}\" -f wav pipe:1 | aplay -q -"}, 
      [:binary, :exit_status]
    )

    {:noreply, {:playing, port, cb}}
  end

  @impl true
  def handle_info({port, {:exit_status, 0}}, {:playing, port, cb}) do
    if cb, do: cb.()
    {:noreply, :idle}
  end
end

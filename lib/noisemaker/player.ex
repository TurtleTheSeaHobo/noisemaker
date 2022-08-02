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

  def play(pid \\ Noisemaker.Player, path) do
    GenServer.cast(pid, {:play, path})
  end
  
  @impl true
  def init(_opts) do
    {:ok, :idle}
  end

  @impl true
  def handle_cast({:play, path}, state) do
    case state do
      {:playing, port} -> :ok = stop_playback(port)
      :idle -> nil
    end

    {:ok, port} = start_playback(path)
    {:noreply, {:playing, port}}
  end

  @impl true
  def handle_info({port, {:exit_status, 0}}, {:playing, port}) do
    {:noreply, :idle}
  end

  defp start_playback(path) do
    {:ok, Port.open({:spawn, "aplay -qD pulse #{path}"}, [:binary, :exit_status])}
  end

  defp stop_playback(port) do
    {:os_pid, os_pid} = Port.info(port, :os_pid)
    Port.close(port)
    System.cmd("kill", ["#{os_pid}"]) 

    :ok
  end
end

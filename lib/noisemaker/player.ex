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

  def stop_all() do
    GenServer.cast(__MODULE__, :stop_all)
  end

  @impl true
  def init(_opts) do
    pregen_audio_files()
    {:ok, %{}}
  end
  
  def ls_r(dir) do
    for x <- File.ls!(dir),
        path = "#{dir}/#{x}" do
      if File.dir?(path), do: ls_r(path), else: path
    end |> List.flatten()
  end

  def pregen_audio_files() do
    files = ls_r("audio")
            |> Enum.filter(fn s -> String.ends_with?(s, ".wav") end)

    for file <- files,
        vol <- [25, 50, 75, 100],
        out = "#{file}.#{vol}",
        !File.exists?(out) do
      cmd_str = "ffmpeg -i #{file} -filter:a \"volume=#{vol / 100}\" -f wav #{out}"
      IO.puts cmd_str
      Port.open({:spawn, cmd_str}, [:binary])
    end
  end

  @impl true
  def handle_cast({:play, path, vol, cb}, state) do
    #case state do
    #  {:playing, port, _cb} -> 
    #    {:os_pid, os_pid} = Port.info(port, :os_pid)
    #    Port.close(port)
    #    System.cmd("kill", ["#{os_pid}"]) 
    #  :idle -> nil
    #end

    port = Port.open(
      {:spawn, "aplay -q #{path}.#{vol}"},
      [:binary, :exit_status]
    )

    {:noreply, Map.put(state, port, cb)}
  end

  def handle_cast(:stop_all, state) do
    System.cmd("killall", ["aplay"]) 
  end

  @impl true
  def handle_info({port, {:exit_status, 0}}, state) do
    {cb, state} = Map.pop(state, port)
    if cb, do: cb.()
    {:noreply, state}
  end
end

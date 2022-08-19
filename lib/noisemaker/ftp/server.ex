defmodule Noisemaker.FTP.Server do
  use GenServer
  alias Noisemaker.Player

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500,
    }
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def store_to(file_name, client_ip, opts \\ []) do
    notify = Keyword.get(opts, :notify)
    GenServer.call(__MODULE__, {:store_to, file_name, client_ip, notify})
  end

  def store(data, client_ip) do
    GenServer.call(__MODULE__, {:store, data, client_ip}) 
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:store_to, file_name, client_ip, notify}, _from, clients) do
    case Map.get(clients, client_ip) do
      nil ->
        {:reply, :ok, Map.put(clients, client_ip, {file_name, notify})}
      other ->
        {:reply, {:error, {:incomplete_operation, other}}, clients}
    end
  end

  @impl true
  def handle_call({:store, data, client_ip}, _from, clients) do
    case Map.get(clients, client_ip) do
      {file_name, notify} ->
        :ok = File.mkdir_p("audio")

	File.ls!("audio")
	|> Enum.filter(&String.starts_with?(&1, file_name))
	|> Enum.map(&File.rm(&1))

        File.write("audio/#{file_name}", data)
        Task.start(fn -> Player.pregen_audio_files() end)
        send(notify, {:store_complete, file_name, byte_size(data)})

        {:reply, :ok, Map.drop(clients, [client_ip])}
      nil ->
        {:reply, {:error, :unknown_client}, clients}
    end
  end
end

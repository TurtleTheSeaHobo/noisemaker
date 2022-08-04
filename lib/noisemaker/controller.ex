defmodule Noisemaker.Controller do
  use GenServer
  alias Noisemaker.Player
  alias Noisemaker.FTP
  defstruct [:volume, :bank, :ftp]

  @default_opts [
    initial_volume: 80,
  ]

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

  def select(n) do
    GenServer.cast(__MODULE__, {:select, n})
  end
  
  def volume() do
    GenServer.cast(__MODULE__, :volume)
  end

  def bank(n) do
    GenServer.cast(__MODULE__, {:bank, n})
  end

  def mode() do
    GenServer.cast(__MODULE__, :mode)
  end

  @impl true
  def init(opts) do
    opts = Keyword.merge(@default_opts, opts)
    state = %__MODULE__{
      volume: opts[:initial_volume],
      bank: 0,
      ftp: true,
    }

    Player.volume(state.volume)

    {:ok, state}
  end

  @impl true
  def handle_cast({:select, n}, state) do
    id = n + state.bank * 8
    Player.play("audio/select_#{id}")
    {:noreply, state}
  end

  def handle_cast(:volume, state) do
    volume = if state.volume == 100 do
      0
    else
      state.volume + 10
    end
    Player.volume(volume)
    {:noreply, %__MODULE__{state | volume: volume}}
  end

  def handle_cast({:bank, n}, state) do
    {:noreply, %__MODULE__{state | bank: n}}
  end

  def handle_cast(:mode, state) do
    if not state.ftp do
      FTP.resume()
      Player.play("audio/ftp_enabled.wav")
      {:noreply, %__MODULE__{state | ftp: true}}
    else
      FTP.suspend()
      Player.play("audio/ftp_disabled.wav")
      {:noreply, %__MODULE__{state | ftp: false}}
    end
  end
end

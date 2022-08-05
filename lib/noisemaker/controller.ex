defmodule Noisemaker.Controller do
  use GenServer
  alias Noisemaker.Driver
  alias Noisemaker.Player
  alias Noisemaker.FTP
  defstruct [:volume, :bank, :led_timer, :ftp]

  @default_opts [
    initial_volume: 75,
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

  def stop_blink() do
    GenServer.cast(__MODULE__, :stop_blink)
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
    Player.play("audio/select_#{id}", fn -> stop_blink() end)

    {:noreply, start_blink(state)}
  end

  def handle_cast(:volume, state) do
    volume = if state.volume == 100 do
      0
    else
      state.volume + 25
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

  def handle_cast(:stop_blink, state) do
    if state.led_timer do
      Driver.led(0, 0)
      Process.cancel_timer(state.led_timer)
    end

    {:noreply, %__MODULE__{state | led_timer: nil}}
  end

  @impl true
  def handle_info({:cont_blink, {even, odd}}, state) do
    Driver.led(even, odd)

    next = case {even, odd} do
      {1, 0} -> {0, 1}
      {0, 1} -> {1, 0}
    end

    Process.send_after(self(), {:cont_blink, next}, 42)

    {:noreply, state}
  end

  def start_blink(state) do
    Driver.led(1, 1)
    # 24 Hz = about 42 ms
    timer = Process.send_after(self(), {:cont_blink, {1, 0}}, 42)
    
    %__MODULE__{state | led_timer: timer}
  end
end

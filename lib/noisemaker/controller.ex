defmodule Noisemaker.Controller do
  use GenServer
  alias Noisemaker.Driver
  alias Noisemaker.Player
  alias Noisemaker.FTP
  defstruct [:volume, :bank, :led_timer, :combo, :combo_timer, :ftp]

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

  def button(symbol, 0) do
    GenServer.cast(__MODULE__, {:depress, symbol})
  end

  def button(symbol, 1) do
    GenServer.cast(__MODULE__, {:release, symbol})
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
      combo: false,
    }

    Driver.led(1, 1)

    {:ok, state}
  end

  @impl true
  def handle_cast({:depress, symbol}, state) do
    new_state = case symbol do
      {:select, n} -> select(n, state)
      {:star, n} -> star(n, state)
      :lever -> lever(state)
      :volume -> volume(state)
      :mode_select -> mode_select(state)
    end

    {:noreply, new_state}
  end

  def handle_cast({:release, _symbol}, state) do
    {:noreply, state}
  end

  def handle_cast(:stop_blink, state) do
    if state.led_timer do
      Driver.led(1, 1)
      Process.cancel_timer(state.led_timer)
    end

    {:noreply, %__MODULE__{state | led_timer: nil}}
  end


  defp volume(state) do
    volume = if state.volume == 100, do: 25, else: state.volume + 25

    %__MODULE__{state | volume: volume}
  end

  defp select(n, state) do
    if state.bank == 2 do
      # bank 2 is a dummy bank with no sound 
      state
    else
      id = n + state.bank * 8
      Player.play("audio/select_#{id}.wav", state.volume, fn -> stop_blink() end)

      start_blink(state)
    end
  end

  defp star(n, state) do
    if state.combo do
      Process.cancel_timer(state.combo_timer)

      case n do
        0 -> toggle_ftp(state)
        1 -> say_ip(state)
      end
    else
      Player.play("audio/star_#{n}.wav", state.volume, fn -> stop_blink() end)
    
      start_blink(state)
    end
  end

  defp lever(state) do
    Player.stop_all()

    start_blink(state)
  end

  defp mode_select(state) do
    timer = Process.send_after(self(), :combo_timeout, 200)

    %__MODULE__{state | combo_timer: timer}
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

  def handle_info(:combo_timeout, state) do
    # not a combo, that means cycle the bank
    bank = if state.bank == 2, do: 0, else: state.bank + 1

    {:noreply, %__MODULE__{state | bank: bank}}
  end

  def start_blink(state) do
    Driver.led(0, 1)
    # 24 Hz = about 42 ms
    timer = Process.send_after(self(), {:cont_blink, {1, 0}}, 42)
    
    %__MODULE__{state | led_timer: timer}
  end

  defp toggle_ftp(state) do
    if state.ftp do
      FTP.suspend()
      Player.play("audio/ftp_disabled.wav", state.volume)
      %__MODULE__{state | ftp: false}
    else
      FTP.resume()
      Player.play("audio/ftp_enabled.wav", state.volume)
      %__MODULE__{state | ftp: true}
    end
  end

  def say_ip(state) do
    say_list = FTP.host_ip()
               |> Tuple.to_list()
               |> Enum.map(&Integer.digits(&1))
               |> Enum.intersperse(["dot"])
               |> List.flatten()
               |> Enum.map(fn x -> "audio/ip/#{x}.wav" end) 

    say(say_list, state.volume)
    state
  end

  defp say(list, vol) do
    list
    |> Enum.reverse()
    |> say(vol, nil)
  end

  defp say([], _vol, cb) do
    cb.()
  end

  defp say([h | t], vol, cb) do
    say(t, fn -> Player.play(h, vol, cb) end)
  end
end

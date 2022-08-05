defmodule Noisemaker.Driver do
  use GenServer
  alias Circuits.GPIO
  alias Noisemaker.Controller

  @default_opts [
    #select_pins: [4, 5, 6, 7, 8, 9, 10, 11, 22, 23],
    #volume_pin: 12,
    #mode_pin: 13,
    button_pins: [4, 5, 6, 22, 27, 9, 10, 11, 12, 13, 16, 22, 23],
    led_pins: {24, 25}, 
  ]

  @pin_map %{
    4  => {:select, 0},
    5  => {:select, 1},
    6  => {:select, 2},
    22 => {:select, 3},
    27 => {:select, 4},
    9  => {:select, 5},
    10 => {:select, 6},
    11 => {:select, 7},
    12 => :volume,
    13 => :mode_select,
    16 => :lever,
    22 => {:star, 0},
    23 => {:star, 1},
  }

  defstruct [:leds, :timers, :buttons]

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

  def led(even, odd) do
    GenServer.cast(__MODULE__, {:led, even, odd}) 
  end
  
  @impl true
  def init(opts) do
    opts = Keyword.merge(@default_opts, opts)
    
    button_pins = for n <- opts[:button_pins] do
      {:ok, pin} = GPIO.open(n, :input, pull_mode: :pullup)
      :ok = GPIO.set_interrupts(pin, :both)
      pin
    end

    timers = for n <- opts[:button_pins], into: %{} do
      {n, nil}
    end

    {led_even, led_odd} = opts[:led_pins]
    {:ok, led_even_pin} = GPIO.open(led_even, :output)
    {:ok, led_odd_pin} = GPIO.open(led_odd, :output)

    state = %__MODULE__{
      leds: {led_even_pin, led_odd_pin},
      timers: timers,
      buttons: button_pins,
    }

    {:ok, state}
  end

  @impl true
  def handle_info({:circuits_gpio, pin, _, value}, state) do
    if state.timers[pin] do
      Process.cancel_timer(state.timers[pin])
    end

    msg = {:debounced, pin, value}
    timer = Process.send_after(self(), msg, 20)

    {:noreply, %__MODULE__{state | timers: %{state.timers | pin => timer}}}
  end

  def handle_info({:debounced, pin, value}, state) do
    IO.puts "debounced pin state: #{pin} = #{value}"
    symbol = @pin_map[pin]
    Controller.button(symbol, value)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:led, even, odd}, state) do
    {even_pin, odd_pin} = state.leds
    GPIO.write(even_pin, even)
    GPIO.write(odd_pin, odd)

    {:noreply, state}
  end

  #defp create_mapping(opts) do
  #  sel_pins = opts[:select_pins]
  #  sel_map = sel_pins
  #            |> Enum.zip(0..(length(sel_pins) - 1))
  #            |> Enum.map(fn {p, i} -> 
  #                 {p, fn -> Controller.select(i) end} 
  #               end)
  #            |> Enum.into(%{})

  #  bank_pins = opts[:bank_pins]
  #  bank_map = bank_pins
  #             |> Enum.zip(0..(length(bank_pins) - 1))
  #             |> Enum.map(fn {p, i} ->
  #                  {p, fn -> Controller.bank(i) end}
  #                end)
  #             |> Enum.into(%{})

  #  sel_map
  #  |> Map.merge(bank_map)
  #  |> Map.merge(%{
  #       opts[:volume_pin] => Controller.volume/0,
  #       opts[:mode_pin] => Controller.mode/0,
  #     })
  #end
end

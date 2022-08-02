defmodule Noisemaker.Driver do
  use GenServer
  alias Circuits.GPIO
  alias Noisemaker.Controller

  @default_opts [
    selector_cb: &Controller.select/1,
    volume_up_cb: &Controller.volume_up/0,
    volume_down_cb: &Controller.volume_down/0,
    selector_pins: [4, 5, 6, 7, 8, 9, 10, 11],
    volume_up_pin: 12,
    volume_down_pin: 13,
    led_even_pin: 14,
    led_odd_pin: 15, 
  ]

  defstruct [:mapping, :pins]

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
    GenServer.start_link(__MODULE__, opts)
  end
  
  @impl true
  def init(opts) do
    opts = Keyword.merge(@default_opts, opts)
    mapping = create_mapping(opts)
    pins = for {n, _cb} <- mapping do
      {:ok, pin} = GPIO.open(n, :input, pull_mode: :pulldown)
      :ok = GPIO.set_interrupts(pin, :falling)
      pin
    end

    {:ok, %__MODULE__{mapping: mapping, pins: pins}}
  end

  @impl true
  def handle_info({:circuits_gpio, pin, _, 0}, state) do
    state.mapping[pin].()
    {:noreply, state}
  end

  defp create_mapping(opts) do
    sel_pins = opts[:selector_pins]
    sel_map = sel_pins
              |> Enum.zip(0..(length(sel_pins) - 1))
              |> Enum.map(fn {p, i} -> 
                   {p, fn -> opts[:selector_cb].(i) end} 
                 end)
              |> Enum.into(%{})
    Map.merge(sel_map, %{
      opts[:volume_up_pin] => opts[:volume_up_cb],
      opts[:volume_down_pin] => opts[:volume_down_cb],
    })
  end
end

defmodule Noisemaker.Driver do
  use GenServer
  alias Circuits.GPIO
  alias Noisemaker.Controller

  @default_opts [
    select_pins: [4, 5, 6, 7, 8, 9, 10, 11],
    bank_pins: [22, 23],
    volume_pin: 12,
    mode_pin: 13,
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
      {:ok, pin} = GPIO.open(n, :input)
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
    sel_pins = opts[:select_pins]
    sel_map = sel_pins
              |> Enum.zip(0..(length(sel_pins) - 1))
              |> Enum.map(fn {p, i} -> 
                   {p, fn -> Controller.select(i) end} 
                 end)
              |> Enum.into(%{})

    bank_pins = opts[:bank_pins]
    bank_map = bank_pins
               |> Enum.zip(0..(length(bank_pins) - 1))
               |> Enum.map(fn {p, i} ->
                    {p, fn -> Controller.bank(i) end}
                  end)
               |> Enum.into(%{})

    sel_map
    |> Map.merge(bank_map)
    |> Map.merge(%{
         opts[:volume_pin] => Controller.volume/0,
         opts[:mode_pin] => Controller.mode/0,
       })
  end
end

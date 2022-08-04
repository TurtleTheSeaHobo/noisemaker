defmodule Noisemaker.FTP.DataProtocol do
  use GenServer
  alias Noisemaker.FTP
  defstruct [:socket, :transport, :client_ip, buffer: ""]

  @behaviour :ranch_protocol

  @impl true
  def start_link(ref, transport, opts) do
    GenServer.start_link(__MODULE__, {ref, transport, opts})
  end

  @impl true
  def init({_ref, transport, _opts} = arg) do
    conn = %__MODULE__{
      transport: transport, 
    }

    {:ok, conn, {:continue, arg}}
  end

  @impl true
  def handle_continue({ref, transport, _opts}, conn) do
    {:ok, socket} = :ranch.handshake(ref)
    {:ok, {client_ip, _port}} = :inet.peername(socket)
    :ok = transport.setopts(socket, active: :true)

    {:noreply, %__MODULE__{conn | socket: socket, client_ip: client_ip}}
  end

  @impl true
  def handle_info({:tcp, _socket, data}, conn) do
    {:noreply, %__MODULE__{conn | buffer: conn.buffer <> data}}
  end

  @impl true
  def handle_info({:tcp_closed, socket}, conn) do
    :ok = conn.transport.close(socket)
    FTP.Server.store(conn.buffer, conn.client_ip)

    {:stop, :normal, conn}
  end
end

defmodule Noisemaker.FTP.CtrlProtocol do
  use GenServer
  alias Noisemaker.FTP
  defstruct [
    :socket, :transport, 
    :host_ip, :client_ip, 
    :data_port, buffer: ""
  ]

  @behaviour :ranch_protocol

  @impl true
  def start_link(ref, transport, opts) do
    GenServer.start_link(__MODULE__, {ref, transport, opts})
  end

  @impl true
  def init({_ref, transport, opts} = arg) do
    host_ip = Keyword.get_lazy(opts, :host, fn -> FTP.host_ip() end)

    conn = %__MODULE__{
      transport: transport, 
      host_ip: host_ip,
      data_port: opts[:data_port],
    }

    {:ok, conn, {:continue, arg}}
  end

  @impl true
  def handle_continue({ref, transport, _opts}, conn) do
    {:ok, socket} = :ranch.handshake(ref)
    {:ok, {client_ip, _port}} = :inet.peername(socket)
    :ok = transport.setopts(socket, active: :true)

    transport.send(socket, "200 bonjour\r\n")

    {:noreply, %__MODULE__{conn | socket: socket, client_ip: client_ip}}
  end

  @impl true
  def handle_info({:tcp, _socket, data}, conn) do
    buffer = conn.buffer <> data

    case parse_command(buffer) do
      {:ok, {argv, rest}} ->
        handle_command(argv, conn)
        {:noreply, %__MODULE__{conn | buffer: rest}}
      {:error, :incomplete} ->
        {:noreply, %__MODULE__{conn | buffer: buffer}}
    end 
  end

  @impl true
  def handle_info({:tcp_closed, socket}, conn) do
    :ok = conn.transport.close(socket)
    {:stop, :normal, conn}
  end

  def handle_info({:store_complete, file_name, size}, conn) do
    send_response(250, "file \"#{file_name}\" (#{size} bytes) received", conn)
    # Noisemaker.Player.play("audio/#{file_name}")
    {:noreply, conn} 
  end

  def parse_command(data) do
    case String.split(data, "\r\n", parts: 2) do
      [complete, rest] ->
        {:ok, {String.split(complete), rest}}
      [_rest] ->
        {:error, :incomplete}
    end
  end

  def handle_command(argv, conn) do
    case argv do
      ["SYST"] ->
        send_response(215, "ERLANG/OTP", conn)
      ["PASV"] ->
        [h0, h1, h2, h3] = Tuple.to_list(conn.host_ip)
        <<p0::8, p1::8>> = <<conn.data_port::16>>
        where = "#{h0}, #{h1}, #{h2}, #{h3}, #{p0}, #{p1}"

        send_response(227, "passive mode enabled (#{where})", conn)
      ["TYPE", "I"] ->
        # forgetting this caused me so much confusion
        send_response(200, "binary transfer enabled", conn)
      ["STOR", file_name] ->
        FTP.Server.store_to(file_name, conn.client_ip, notify: self())

        send_response(125, "send it", conn)
      ["QUIT"] ->
        send_response(221, "adios", conn)
        conn.transport.close(conn.socket)
    end
  end

  def send_response(code, resp, conn) do
    msg = "#{code} #{resp}\r\n"
    conn.transport.send(conn.socket, msg)
  end
end

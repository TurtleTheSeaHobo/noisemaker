defmodule Noisemaker.FTP.DataListener do
  alias Noisemaker.FTP

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
    ranch_opts = [port: opts[:data_port]]
    
    :ranch.start_listener(
      :ftp_server_data, :ranch_tcp, 
      ranch_opts, FTP.DataProtocol, 
      []
    )
  end
end

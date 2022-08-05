defmodule Noisemaker.FTP.CtrlListener do
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

  def start_link(opts) do
    ranch_opts = [port: opts[:ctrl_port]]
    
    :ranch.start_listener(
      :ftp_server_ctrl, :ranch_tcp, 
      ranch_opts, FTP.CtrlProtocol, 
      [data_port: opts[:data_port]]
    )
  end
end

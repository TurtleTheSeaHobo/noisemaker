defmodule Noisemaker.FTP do
  use Supervisor
  
  @default_opts [
    ctrl_port: 2121, 
    data_port: 2120,
  ]

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    opts = Keyword.merge(@default_opts, opts)
    children = [
      {__MODULE__.Server, opts},
      {__MODULE__.CtrlListener, opts},
      {__MODULE__.DataListener, opts},
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  def suspend() do
    :ranch.suspend_listener(:ftp_server_ctrl)
    :ranch.suspend_listener(:ftp_server_data)
  end

  def resume() do
    :ranch.resume_listener(:ftp_server_ctrl)
    :ranch.resume_listener(:ftp_server_data)
  end
end

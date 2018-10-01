defmodule Gossip do
  use Application

  def start(_type, _args) do
    Gossip.Supervisor.start_link([])
  end
end

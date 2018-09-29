defmodule Gossip do
  use Application

  def start(_type, _args) do
    Gossip.P2PSupervisor.start_link([])
  end
end

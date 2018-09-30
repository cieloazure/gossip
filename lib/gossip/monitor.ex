defmodule Gossip.Monitor do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    num_nodes = Keyword.get(opts, :num_nodes)
    {:ok, child_pids} = Gossip.P2PSupervisor.start_children(Gossip.P2PSupervisor, num_nodes, self(), "full")
    pid = Enum.random(child_pids)
    send(pid, {:fact, 42, -1, nil})
    convergence_events = []
    {:ok, {convergence_events}}
  end

  def handle_info({:convergence_event, pid}, {convergence_events}) do
    IO.puts "Received convergence event from #{inspect(pid)}"
    convergence_events = [pid | convergence_events]
    if length(convergence_events) == 10 do
      IO.puts "Convergence for network reached! Shutting monitor down!"
      System.stop(1)
    end
    {:noreply, {convergence_events}}
  end
end

defmodule Gossip.Monitor do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    IO.puts "Execution status"
    num_nodes = Keyword.get(opts, :num_nodes)
    topology = Keyword.get(opts, :topology)
    {:ok, child_pids} = Gossip.P2PSupervisor.start_children(Gossip.P2PSupervisor, num_nodes, self(), topology)
    pid = Enum.random(child_pids)
    send(pid, {:fact, 42, -1, nil})
    convergence_events = []
    {:ok, {convergence_events, num_nodes}}
  end

  def handle_info({:convergence_event, pid}, {convergence_events, num_nodes}) do

    #IO.puts "Received convergence event from #{inspect(pid)}"
    convergence_events = [pid | convergence_events]
    len_convergence_events = length(convergence_events)
    if len_convergence_events == num_nodes - 1 do
      System.stop(1)
    else
      ProgressBar.render(len_convergence_events, num_nodes)
    end
    {:noreply, {convergence_events, num_nodes}}
  end
end

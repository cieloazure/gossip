defmodule Gossip.ConvergenceMonitor do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def start_simulation(pid) do
    GenServer.call(pid, {:start})
  end

  def init(opts) do
    num_nodes = Keyword.get(opts, :num_nodes)
    topology = Keyword.get(opts, :topology)
    algorithm = Keyword.get(opts, :algorithm)
    convergence_events = []
    {:ok, {convergence_events, num_nodes, topology, algorithm, []}}
  end

  def handle_call(
        {:start},
        _from,
        {convergence_events, num_nodes, topology, algorithm, old_child_pids}
      ) do
    {:ok, child_pids} =
      Gossip.Supervisor.start_children(Gossip.Supervisor, num_nodes, self(), topology)

    Gossip.Supervisor.initiate_algorithm(child_pids, algorithm)
    new_child_pids = old_child_pids ++ child_pids
    {:reply, :ok, {convergence_events, num_nodes, topology, algorithm, new_child_pids}}
  end

  def handle_info(
        {:convergence_event, pid},
        {convergence_events, num_nodes, topology, algorithm, child_pids}
      ) do
    try do
      Logger.info("Convergence of node #{inspect(pid)}")
    rescue
      RuntimeError -> IO.puts("Convergence of node #{inspect(pid)}")
    end

    convergence_events = [pid | convergence_events] |> Enum.dedup()
    len_convergence_events = length(convergence_events)

    if len_convergence_events >= num_nodes do
      ProgressBar.render(num_nodes, num_nodes)

      IO.inspect(
        Enum.map(child_pids, fn pid ->
          {_, fact, count, status, _, _} = :sys.get_state(pid)
          {pid, fact, count, status}
        end),
        limit: :infinity
      )

      # Process.sleep(1000)
      # System.stop(0)
    else
      ProgressBar.render(len_convergence_events, num_nodes)
    end

    {:noreply, {convergence_events, num_nodes, topology, algorithm, child_pids}}
  end
end

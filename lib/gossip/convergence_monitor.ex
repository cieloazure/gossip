defmodule Gossip.ConvergenceMonitor do
  @moduledoc """
  A module to monitor the convergence of topology for a given algorithm
  """
  use GenServer
  require Logger

  @doc """
  Starts the monitor
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Starts the simulation for given nodes, topology and alogrithm
  """
  def start_simulation(pid) do
    GenServer.call(pid, {:start}, :infinity)
  end

  # Server callbacks

  @doc """
  Initiate the state of the monitor
  """
  @impl true
  def init(opts) do
    num_nodes = Keyword.get(opts, :num_nodes)
    topology = Keyword.get(opts, :topology)
    algorithm = Keyword.get(opts, :algorithm)
    convergence_events = []
    {:ok, {convergence_events, num_nodes, topology, algorithm, [], nil}}
  end

  @doc """
  Callback for starting simulation
  """
  @impl true
  def handle_call(
        {:start},
        {from_pid, _ref},
        {convergence_events, num_nodes, topology, algorithm, old_child_pids, _report_pid}
      ) do
    {:ok, child_pids} =
      Gossip.Supervisor.start_children(Gossip.Supervisor, num_nodes, self(), topology, algorithm)

    Gossip.Supervisor.initiate_algorithm(child_pids, algorithm)
    new_child_pids = old_child_pids ++ child_pids
    {:reply, :ok, {convergence_events, num_nodes, topology, algorithm, new_child_pids, from_pid}}
  end

  @doc """
  Callback function to gather the convergence events from the nodes of the topology
  """
  @impl true
  def handle_info(
        {:convergence_event, pid},
        {convergence_events, num_nodes, topology, algorithm, child_pids, report_pid}
      ) do
    try do
      Logger.debug("Convergence of node #{inspect(pid)}")
    rescue
      RuntimeError -> IO.puts("Convergence of node #{inspect(pid)}")
    end

    convergence_events =
      if !Enum.member?(convergence_events, pid) do
        [pid | convergence_events]
      else
        convergence_events
      end

    len_convergence_events = length(convergence_events)

    ProgressBar.render(len_convergence_events, num_nodes)

    if len_convergence_events == num_nodes do
      # IO.inspect(
      # Enum.map(child_pids, fn pid ->
      # {_, fact, count, status, _, _} = :sys.get_state(pid)
      # {pid, fact, count, status}
      # end),
      # limit: :infinity
      # )

      send(report_pid, {:convergence_reached, true})
    end

    {:noreply, {convergence_events, num_nodes, topology, algorithm, child_pids, report_pid}}
  end
end

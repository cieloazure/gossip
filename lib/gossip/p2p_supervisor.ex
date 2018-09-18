defmodule Gossip.P2PSupervisor do
  use DynamicSupervisor
  require Logger

  def start_link(arg) do
    Logger.info("starting link")
    DynamicSupervisor.start_link(__MODULE__, arg, name: Gossip.P2PSupervisor)
  end

  def start_children(supervisor, num_nodes, topology \\ "full") do
    Logger.info("Starting children genserver....")

    if num_nodes <= 0,
      do: raise(ArgumentError, message: "num_nodes(argument 2) should be greater than 0")

    child_pids =
      for _n <- 1..num_nodes do
        {:ok, child_pid} = DynamicSupervisor.start_child(supervisor, Gossip.Node)
        child_pid
      end

    create_topology(topology, child_pids)
    send_fact(child_pids, {:fact, "The answer to the question is 42"})
    {:ok, child_pids}
  end

  def send_fact(child_pids, {:fact, fact}) do
    random_child_pid = Enum.random(child_pids)
    send(random_child_pid, {:fact, fact})
  end

  # Callback
  @impl true
  def init(_args) do
    Logger.info("Starting supervisor...")
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # Private functions
  # TODO: Implement topology functions
  defp create_topology(topology, child_pids) do
    case topology do
      "full" -> create_full_network(child_pids)
      "3D" -> create_3d_network(child_pids)
      "rand2D" -> create_rand_2d_network(child_pids)
      "torrus" -> create_torrus_network(child_pids)
      "line" -> create_line_network(child_pids)
      "imp2D" -> create_imperfect_line_2d_network(child_pids)
      _ -> raise_invalid_topology_error(child_pids)
    end
  end

  defp create_full_network(child_pids) do
    Logger.info("creating full network...")

    Enum.each(child_pids, fn child_pid ->
      new_neighbours = MapSet.difference(MapSet.new(child_pids), MapSet.new([child_pid]))
      Gossip.Node.add_new_neighbours(child_pid, new_neighbours)
    end)
  end

  defp create_line_network(child_pids) do
    Logger.info("creating line network....")

    Enum.chunk_every(child_pids, 2, 1, :discard)
    |> Enum.each(fn [a, b] ->
      Gossip.Node.add_new_neighbour(a, b)
      Gossip.Node.add_new_neighbour(b, a)
    end)
  end

  defp create_3d_network(_child_pids) do
    Logger.info("creating 3d network...")
  end

  defp create_rand_2d_network(_child_pids) do
    Logger.info("creating rand 2d network...")
  end

  defp create_torrus_network(_child_pids) do
    Logger.info("creating torrus network...")
  end

  defp create_imperfect_line_2d_network(child_pids) do
    Logger.info("creating imperfect line 2d network...")
    create_line_network(child_pids)

    Enum.each(child_pids, fn child_pid ->
      rand_child = Enum.random(child_pids)
      Gossip.Node.add_new_neighbour(child_pid, rand_child)
    end)
  end

  defp raise_invalid_topology_error(_child_pids) do
    Logger.info("raising invalid topology error.....")
    raise ArgumentError, "topology(argument 3) is invalid"
  end
end

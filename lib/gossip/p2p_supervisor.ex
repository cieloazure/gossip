defmodule Gossip.P2PSupervisor do 
  use DynamicSupervisor

  def start_link(arg) do
    IO.puts "starting link"
    DynamicSupervisor.start_link(__MODULE__, arg, name: Gossip.P2PSupervisor)
  end

  def start_children(supervisor, num_nodes, topology) do
    IO.puts "Starting children genserver...."
    child_pids = for _n <- 1..num_nodes do 
      {:ok, child_pid} = DynamicSupervisor.start_child(supervisor, Gossip.Node)
      child_pid
    end
    IO.inspect child_pids
    create_topology(topology, child_pids)
    #send_rumor(child_pids, {:fact, "The answer to the question is 42"})
  end

  def send_rumor(child_pids, {:fact, fact}) do
    random_child_pid = Enum.random(child_pids)
    send random_child_pid, {:fact, fact}
  end

  # Callback
  @impl true
  def init(_args) do
    IO.puts "Starting supervisor..."
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
      "imp2D" -> create_imperfect_line_2d_network(child_pids)
      "_" -> raise_invalid_topology_error(child_pids)
    end
  end

  defp create_full_network(child_pids) do
    IO.puts "creating full network..."
    Enum.each(child_pids, fn child_pid -> 
      IO.inspect child_pid
      new_neighbours = MapSet.difference(MapSet.new(child_pids), MapSet.new([child_pid]))
      IO.inspect new_neighbours
      Gossip.Node.add_new_neighbours(child_pid, new_neighbours)
    end)
  end

  defp create_3d_network(_child_pids) do
    IO.puts "creating 3d network..."
  end

  defp create_rand_2d_network(_child_pids)do
    IO.puts "creating rand 2d network..."
  end

  defp create_torrus_network(_child_pids)do
    IO.puts "creating torrus network..."
  end

  defp create_imperfect_line_2d_network(_child_pids)do
    IO.puts "creating imperfect line 2d network..."
  end

  defp raise_invalid_topology_error(_child_pids) do
    IO.puts "raising invalid topology error....."
  end
end

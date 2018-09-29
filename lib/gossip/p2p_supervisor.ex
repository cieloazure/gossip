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

  defp create_3d_network(child_pids) do
    Logger.info("creating 3d network...")
    grid_slots = create_3d_grid_slots(length(child_pids))
    actor_grid = Enum.zip(child_pids, Enum.take_random(grid_slots, length(child_pids)))

    for {pid1, {x1, y1, z1}} <- actor_grid,
        {pid2, {x2, y2, z2}} <-
          MapSet.to_list(
            MapSet.difference(MapSet.new(actor_grid), MapSet.new([{pid1, {x1, y1, z1}}]))
          ) do
      if grid_3d_neighbour?(x1, y1, z1, x2, y2, z2) do
        Gossip.Node.add_new_neighbour(pid1, pid2)
      end
    end
  end

  defp create_rand_2d_network(child_pids) do
    # TODO: create_grid_slots based on number of child_pids
    # Currently, the rand2D grid will support 16 * 16 nodes = 256 nodes
    # Value of grid slots are hard coded, which need to be dynamic 
    Logger.info("creating rand 2d network...")
    grid_slots = create_grid_slots()

    actor_grid =
      Enum.map(child_pids, fn child_pid ->
        {node, _list} = List.pop_at(grid_slots, :rand.uniform(length(child_pids)) - 1)
        {x, y} = node
        {child_pid, x, y}
      end)

    for {pid1, x1, y1} <- actor_grid,
        {pid2, x2, y2} <-
          MapSet.to_list(MapSet.difference(MapSet.new(actor_grid), MapSet.new([{pid1, x1, y1}]))) do
      if grid_neighbour?(x1, y1, x2, y2) do
        Gossip.Node.add_new_neighbour(pid1, pid2)
      end
    end
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

  defp create_grid_slots do
    grid_values = get_grid_values()
    List.flatten(Enum.map(grid_values, fn x -> Enum.map(grid_values, fn y -> {x, y} end) end))
  end

  defp get_grid_values do
    Enum.map(0..20, fn x -> x / 10 end)
    |> Enum.map(fn x -> x / 2 end)
  end

  defp grid_neighbour?(x1, y1, x2, y2) do
    {a, b} =
      cond do
        x1 != x2 and y1 != y2 ->
          {nil, nil}

        x1 == x2 and y1 == y2 ->
          {nil, nil}

        x1 == x2 ->
          {y1, y2}

        y1 == y2 ->
          {x1, x2}
      end

    if a != nil and b != nil do
      if min(a, b) + 0.1 >= max(a, b) do
        true
      else
        false
      end
    else
      false
    end
  end

  defp create_3d_grid_slots(num_nodes) do
    # Considering a cube grid 
    # Hence num_nodes ^ (1/3)
    size =
      if num_nodes > 8 do
        round(:math.ceil(:math.pow(num_nodes, 1 / 3))) - 1
      else
        1
      end

    List.flatten(
      Enum.map(0..size, fn x ->
        Enum.map(0..size, fn y ->
          Enum.map(0..size, fn z -> {x, y, z} end)
        end)
      end)
    )
  end

  defp grid_3d_neighbour?(x1, y1, z1, x2, y2, z2) do
    {a, b} =
      cond do
        x1 == x2 and y1 == y2 ->
          {z1, z2}

        x1 == x2 and z1 == z2 ->
          {y1, y2}

        y1 == y2 and z1 == z2 ->
          {x1, x2}

        true ->
          {nil, nil}
      end

    if a != nil and b != nil do
      if min(a, b) + 1 >= max(a, b) do
        true
      else
        false
      end
    else
      false
    end
  end
end

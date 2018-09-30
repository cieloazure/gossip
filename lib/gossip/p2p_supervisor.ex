defmodule Gossip.P2PSupervisor do 
  use DynamicSupervisor
  require Logger

  def start_link(arg) do
    Logger.info("starting link")
    DynamicSupervisor.start_link(__MODULE__, arg, name: Gossip.P2PSupervisor)
  end

  def start_children(supervisor, num_nodes, topology \\ "full", algorithm \\ "gossip") do
    Logger.info("Starting children genserver....")

    if num_nodes <= 0,
      do: raise(ArgumentError, message: "num_nodes(argument 2) should be greater than 0")

    child_pids =
      for n <- 1..num_nodes do 
        {:ok, child_pid} = DynamicSupervisor.start_child(supervisor, {Gossip.NewNode, [node_number: n]})
        child_pid
      end

    create_topology(topology, child_pids)
    # initiate_algorithm(algorithm, child_pids)
    # send_fact(child_pids, {:fact, "The answer to the question is 42"})
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

  defp initiate_algorithm(algorithm, child_pids) do
    case algorithm do
      "gossip" -> send_fact(child_pids, {:fact, 42})
      "pushsum" -> send(Enum.random(child_pids), {:pushsum})
      _ -> raise_invalid_algorithm_error()
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
    Logger.info("creating rand 2d network...")
    grid_slots = create_2d_grid_slots(length(child_pids))

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

  defp create_torrus_network(child_pids) do
    IO.puts "creating torus network..."
    n = length(child_pids)
    {rows, columns} = set_torus_dimensions(n)
    IO.puts("create_torrus_network #{rows}, #{columns}")
    Enum.each(0..n - 2, fn index -> 
      new_neighbours = []
      IO.puts("new_neighbours #{index}")
      
      # horizontally closed ends
      new_neighbours = if rem(index, columns) == 0 do
        List.insert_at(new_neighbours, 0, Enum.at(child_pids, index + columns - 1))
        else
          new_neighbours 
      end
      
      # vertically closed ends
      new_neighbours = if index < columns do
        List.insert_at(new_neighbours, 0, Enum.at(child_pids, columns * (rows - 1) + index))
        else
          new_neighbours
      end
      
      # horizontal connection
      new_neighbours = if rem(index, columns) != columns - 1 do
        List.insert_at(new_neighbours, 0, Enum.at(child_pids, index + 1))
        else
          new_neighbours
      end
      
      # vertical connection
      new_neighbours = if index < columns * (rows - 1) do
        List.insert_at(new_neighbours, 0, Enum.at(child_pids, index + columns))
        else
          new_neighbours
      end
      
      IO.inspect(new_neighbours)

      Gossip.Node.add_new_neighbours_dual(Enum.at(child_pids, index), new_neighbours)     
    end)
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

  defp raise_invalid_algorithm_error() do
    Logger.info("raising invalid algorithm error.....")
    raise ArgumentError, "algorithm(argument 4) is invalid"
  end

  defp create_2d_grid_slots(num_nodes) do
    grid_values = get_grid_values(num_nodes)
    List.flatten(Enum.map(grid_values, fn x -> Enum.map(grid_values, fn y -> {x, y} end) end))
  end

  defp get_grid_values(num_nodes) do
    step =
      if num_nodes > 100 do
        Float.round(1 / (round(:math.ceil(:math.sqrt(num_nodes))) - 1), 3)
      else
        0.1
      end

    generate_values(0, step)
  end

  defp generate_values(x, step, l \\ [])

  defp generate_values(x, _step, l) when x == 1 do
    Enum.dedup(l) |> Enum.reverse()
  end

  defp generate_values(x, step, l) when x < 1 do
    l = [x | l]
    x = Float.round(x / 1 + step / 1, 2)

    x =
      if x > 1 do
        :math.floor(x)
      else
        x
      end

    l = [x | l]
    generate_values(x, step, l)
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
    # Considering a cuboid grid 
    a = round(:math.pow(num_nodes, 1 / 3))
    b = round(:math.sqrt(num_nodes / a))
    c = round(:math.ceil(num_nodes / (a * b)))

    # size =
    # if num_nodes > 8 do
    # round(:math.ceil(:math.pow(num_nodes, 1 / 3))) - 1
    # else
    # 1
    # end

    List.flatten(
      Enum.map(0..(a - 1), fn x ->
        Enum.map(0..(b - 1), fn y ->
          Enum.map(0..(c - 1), fn z -> {x, y, z} end)
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

  defp set_torus_dimensions(n) do
    s = trunc(:math.sqrt(n))
    find_factors(n, s)
    # IO.puts("set_torus_dimensions #{a}, #{b}")

  end

  defp find_factors(n, s) do
    cond do
      rem(n, s) == 0 -> {s, trunc(n/s)}
      true -> if s-1 != 0, do: find_factors(n, s-1)
    end
  end

end

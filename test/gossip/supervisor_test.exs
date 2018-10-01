defmodule Gossip.SupervisorTest do
  use ExUnit.Case

  setup_all do
    {:ok, pid} =
      Gossip.ConvergenceMonitor.start_link(num_nodes: 5, topology: "full", algorithm: "gossip")

    [monitor: pid]
  end

  describe "start_children:" do
    test "starts num_nodes of children", context do
      {:ok, child_pids} =
        Gossip.Supervisor.start_children(Gossip.Supervisor, 5, context[:monitor])

      assert length(child_pids) == 5
    end

    test "gives error if num_nodes is invalid", context do
      assert_raise ArgumentError, "num_nodes(argument 2) should be greater than 0", fn ->
        Gossip.Supervisor.start_children(Gossip.Supervisor, 0, context[:monitor])
      end

      assert_raise ArgumentError, "num_nodes(argument 2) should be greater than 0", fn ->
        Gossip.Supervisor.start_children(Gossip.Supervisor, -1, context[:monitor])
      end
    end

    test "gives error if topology is invalid", context do
      assert_raise ArgumentError, "topology(argument 3) is invalid", fn ->
        Gossip.Supervisor.start_children(Gossip.Supervisor, 5, context[:monitor], "abcd")
      end
    end
  end

  describe "create_topology:" do
    test "creates a full network when no topology argument is passed", context do
      {:ok, child_pids} =
        Gossip.Supervisor.start_children(Gossip.Supervisor, 5, context[:monitor])

      Enum.each(child_pids, fn child_pid ->
        neighbours = MapSet.difference(MapSet.new(child_pids), MapSet.new([child_pid]))
        assert neighbours == Gossip.Node.get_neighbours(child_pid)
      end)
    end

    test "creates a full network when explicit argument is passed", context do
      {:ok, child_pids} =
        Gossip.Supervisor.start_children(Gossip.Supervisor, 5, context[:monitor], "full")

      Enum.each(child_pids, fn child_pid ->
        neighbours = MapSet.difference(MapSet.new(child_pids), MapSet.new([child_pid]))
        assert neighbours == Gossip.Node.get_neighbours(child_pid)
      end)
    end

    test "creates a line network", context do
      {:ok, child_pids} =
        Gossip.Supervisor.start_children(Gossip.Supervisor, 5, context[:monitor], "line")

      first_actor_size = MapSet.size(Gossip.Node.get_neighbours(List.first(child_pids)))
      last_actor_size = MapSet.size(Gossip.Node.get_neighbours(List.last(child_pids)))
      assert first_actor_size == 1
      assert last_actor_size == 1

      Enum.slice(child_pids, 1..-2)
      |> Enum.each(fn child_pid ->
        middle_actor_size = MapSet.size(Gossip.Node.get_neighbours(child_pid))
        assert middle_actor_size == 2
      end)
    end

    test "creates imperfect line 2d network", context do
      {:ok, child_pids} =
        Gossip.Supervisor.start_children(Gossip.Supervisor, 5, context[:monitor], "imp2D")

      first_actor_size = MapSet.size(Gossip.Node.get_neighbours(List.first(child_pids)))
      last_actor_size = MapSet.size(Gossip.Node.get_neighbours(List.last(child_pids)))
      assert first_actor_size == 1 or first_actor_size == 2
      assert last_actor_size == 1 or last_actor_size == 2

      Enum.slice(child_pids, 1..-2)
      |> Enum.each(fn child_pid ->
        middle_actor_size = MapSet.size(Gossip.Node.get_neighbours(child_pid))
        assert middle_actor_size == 2 or middle_actor_size == 3
      end)
    end

    test "creates a random 2d network of < 100 nodes", context do
      {:ok, child_pids} =
        Gossip.Supervisor.start_children(Gossip.Supervisor, 50, context[:monitor], "rand2D")

      neighbour_sizes =
        Enum.map(child_pids, fn child_pid ->
          MapSet.size(Gossip.Node.get_neighbours(child_pid))
        end)

      assert Enum.any?(neighbour_sizes, fn size -> size >= 1 end)
    end

    test "creates a random 2d network > 100 nodes", context do
      {:ok, child_pids} =
        Gossip.Supervisor.start_children(Gossip.Supervisor, 225, context[:monitor], "rand2D")

      neighbour_sizes =
        Enum.map(child_pids, fn child_pid ->
          MapSet.size(Gossip.Node.get_neighbours(child_pid))
        end)

      assert Enum.any?(neighbour_sizes, fn size -> size >= 1 end)
    end

    test "creates a full 3d network when there are 8 nodes", context do
      {:ok, child_pids} =
        Gossip.Supervisor.start_children(Gossip.Supervisor, 8, context[:monitor], "3D")

      neighbour_sizes =
        Enum.map(child_pids, fn child_pid ->
          MapSet.size(Gossip.Node.get_neighbours(child_pid))
        end)

      assert Enum.all?(neighbour_sizes, fn size -> size == 3 end)
    end

    test "creates a full 3d network when there are 4 nodes", context do
      {:ok, child_pids} =
        Gossip.Supervisor.start_children(Gossip.Supervisor, 4, context[:monitor], "3D")

      neighbour_sizes =
        Enum.map(child_pids, fn child_pid ->
          MapSet.size(Gossip.Node.get_neighbours(child_pid))
        end)

      assert Enum.all?(neighbour_sizes, fn size -> size != 0 end)
    end

    test "creates a full 3d network when there are 400 nodes", context do
      {:ok, child_pids} =
        Gossip.Supervisor.start_children(Gossip.Supervisor, 400, context[:monitor], "3D")

      neighbour_sizes =
        Enum.map(child_pids, fn child_pid ->
          MapSet.size(Gossip.Node.get_neighbours(child_pid))
        end)

      assert Enum.all?(neighbour_sizes, fn size -> size != 0 end)
    end

    test "creates a full 3d network when there are 1000 nodes", context do
      {:ok, child_pids} =
        Gossip.Supervisor.start_children(Gossip.Supervisor, 1000, context[:monitor], "3D")

      neighbour_sizes =
        Enum.map(child_pids, fn child_pid ->
          MapSet.size(Gossip.Node.get_neighbours(child_pid))
        end)

      assert Enum.all?(neighbour_sizes, fn size -> size != 0 end)
    end
  end

  @tag :pending
  test "creates a torrus network"

  @tag :pending
  test "sends rumor to a random child"
end

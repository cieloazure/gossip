defmodule Gossip.P2PSupervisorTest do
  use ExUnit.Case

  describe "start_children:" do
    test "starts num_nodes of children" do
      {:ok, child_pids} = Gossip.P2PSupervisor.start_children(Gossip.P2PSupervisor, 5)
      assert length(child_pids) == 5
    end

    test "gives error if num_nodes is invalid" do
      assert_raise ArgumentError, "num_nodes(argument 2) should be greater than 0", fn ->
        Gossip.P2PSupervisor.start_children(Gossip.P2PSupervisor, 0)
      end

      assert_raise ArgumentError, "num_nodes(argument 2) should be greater than 0", fn ->
        Gossip.P2PSupervisor.start_children(Gossip.P2PSupervisor, -1)
      end
    end

    test "gives error if topology is invalid" do
      assert_raise ArgumentError, "topology(argument 3) is invalid", fn ->
        Gossip.P2PSupervisor.start_children(Gossip.P2PSupervisor, 5, "abcd")
      end
    end
  end


  describe "create_topology:" do
    test "creates a full network when no topology argument is passed" do
      {:ok, child_pids} = Gossip.P2PSupervisor.start_children(Gossip.P2PSupervisor, 5)

      Enum.each(child_pids, fn child_pid ->
        neighbours = MapSet.difference(MapSet.new(child_pids), MapSet.new([child_pid]))
        assert neighbours == Gossip.Node.get_neighbours(child_pid)
      end)
    end

    test "creates a full network when explicit argument is passed" do
      {:ok, child_pids} = Gossip.P2PSupervisor.start_children(Gossip.P2PSupervisor, 5, "full")

      Enum.each(child_pids, fn child_pid ->
        neighbours = MapSet.difference(MapSet.new(child_pids), MapSet.new([child_pid]))
        assert neighbours == Gossip.Node.get_neighbours(child_pid)
      end)
    end

    test "creates a line network" do
      {:ok, child_pids} = Gossip.P2PSupervisor.start_children(Gossip.P2PSupervisor, 5, "line")
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

    test "creates imperfect line 2d network" do
      {:ok, child_pids} = Gossip.P2PSupervisor.start_children(Gossip.P2PSupervisor, 5, "imp2D")
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

    test "creates a random 2d network" do
      {:ok, child_pids} = Gossip.P2PSupervisor.start_children(Gossip.P2PSupervisor, 50, "rand2D")
       neighbour_sizes = Enum.map(child_pids, fn child_pid ->
        MapSet.size(Gossip.Node.get_neighbours(child_pid))
      end) 
      assert Enum.any?(neighbour_sizes, fn size -> size >= 1 end)
    end
  end

  @tag :pending
  test "creates a 3d network"

  @tag :pending
  test "creates a torrus network"

  @tag :pending
  test "sends rumor to a random child"
end

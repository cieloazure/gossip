defmodule Gossip.NodeV2Test do
  use ExUnit.Case

  describe "gossip algorithm:" do
    test "full topology with 100 nodes" do
      {:ok, pid} =
        Gossip.ConvergenceMonitor.start_link(
          num_nodes: 100,
          topology: "full",
          algorithm: "gossip"
        )

      Gossip.ConvergenceMonitor.start_simulation(pid)

      receive do
        {:convergence_reached, status} ->
          IO.puts("Execution complete! Convergence reached: #{status}")
          assert status
      after
        5000 ->
          flunk("Convergence not reached")
      end
    end

    test "line topology with 100 nodes" do
      {:ok, pid} =
        Gossip.ConvergenceMonitor.start_link(
          num_nodes: 100,
          topology: "line",
          algorithm: "gossip"
        )

      Gossip.ConvergenceMonitor.start_simulation(pid)

      receive do
        {:convergence_reached, status} ->
          IO.puts("Execution complete! Convergence reached: #{status}")
          assert status
      after
        5000 ->
          flunk("Convergence not reached")
      end
    end

    test "imperfect line topology with 100 nodes" do
      {:ok, pid} =
        Gossip.ConvergenceMonitor.start_link(
          num_nodes: 100,
          topology: "imp2d",
          algorithm: "gossip"
        )

      Gossip.ConvergenceMonitor.start_simulation(pid)

      receive do
        {:convergence_reached, status} ->
          IO.puts("Execution complete! Convergence reached: #{status}")
          assert status
      after
        5000 ->
          flunk("Convergence not reached")
      end
    end

    test "rand2d topology with 100 nodes" do
      {:ok, pid} =
        Gossip.ConvergenceMonitor.start_link(
          num_nodes: 100,
          topology: "rand2d",
          algorithm: "gossip"
        )

      Gossip.ConvergenceMonitor.start_simulation(pid)

      receive do
        {:convergence_reached, status} ->
          IO.puts("Execution complete! Convergence reached: #{status}")
          assert status
      after
        5000 ->
          flunk("Convergence not reached")
      end
    end

    test "3d topology with 100 nodes" do
      {:ok, pid} =
        Gossip.ConvergenceMonitor.start_link(num_nodes: 100, topology: "3d", algorithm: "gossip")

      Gossip.ConvergenceMonitor.start_simulation(pid)

      receive do
        {:convergence_reached, status} ->
          IO.puts("Execution complete! Convergence reached: #{status}")
          assert status
      after
        5000 ->
          flunk("Convergence not reached")
      end
    end

    test "torrus topology with 100 nodes" do
      {:ok, pid} =
        Gossip.ConvergenceMonitor.start_link(
          num_nodes: 100,
          topology: "torrus",
          algorithm: "gossip"
        )

      Gossip.ConvergenceMonitor.start_simulation(pid)

      receive do
        {:convergence_reached, status} ->
          IO.puts("Execution complete! Convergence reached: #{status}")
          assert status
      after
        5000 ->
          flunk("Convergence not reached")
      end
    end
  end

end

defmodule Main do
  def run(num_nodes, topology, algorithm) do
    
    #TODO : Add error checking
    {:ok, pid} = Gossip.ConvergenceMonitor.start_link([num_nodes: num_nodes, topology: topology, algorithm: algorithm])
    Gossip.ConvergenceMonitor.start_simulation(pid)
    loop()
  end

  def loop do
    receive do
      {:convergence_reached, status} -> 
        IO.puts "Execution complete! Convergence reached: #{status}"
    end
  end
end

usage_string = "Invalid arguments to the command\nUsage: mix run proj2.exs --no-halt <numNodes:int> <topology:string> <algorithm:string>"
if length(System.argv) != 3 do
  raise(ArgumentError, usage_string)
end

[num_nodes, topology, algorithm]  = System.argv
num_nodes = String.to_integer(num_nodes)

{time, :ok} = :timer.tc(Main, :run, [num_nodes, topology, algorithm])


# Enum.each(Supervisor.which_children(Gossip.Supervisor), fn child -> 
#   pid = Enum.at(Tuple.to_list(child), 1)
#   {_neighbours, sum, weight, _round_counter, _state, _fact_monger, _monitor, _most_recent_actors_ratio} = :sys.get_state(pid)
#   IO.puts("\n" <> inspect(pid) <> ":_" <> inspect(sum/weight))
# end)


IO.puts("\nexecution time: #{inspect(time/1000)} ms")
usage_string = "Invalid arguments to the command\nUsage: mix run proj2.exs --no-halt <numNodes:int> <topology:string> <algorithm:string>"
if length(System.argv) != 3 do
   raise(ArgumentError, usage_string)
end
#TODO : Add error checking
[num_nodes, topology, algorithm]  = System.argv
IO.puts "num_nodes = #{num_nodes}"
{:ok, pid} = Gossip.ConvergenceMonitor.start_link([num_nodes: String.to_integer(num_nodes), topology: topology, algorithm: algorithm])
# {time, {:ok, pid}} = :timer.tc(Gossip.ConvergenceMonitor, :start_link, [[num_nodes: String.to_integer(num_nodes), topology: topology, algorithm: algorithm]])
# Gossip.ConvergenceMonitor.start_simulation(pid)
{time, _value} = :timer.tc(Gossip.ConvergenceMonitor, :start_simulation, [pid])

IO.puts "\ntime = #{time/1000} ms"

File.rm("node_states.txt")
{:ok, file} = File.open "node_states.txt", [:write]
IO.write(file, "#{num_nodes} " <> topology <> " " <> algorithm)
IO.write(file, "\nexecution time = #{time/1000} ms")
IO.write(file, "\nNode States:\n")

case algorithm do
	"gossip" ->
        Enum.each(Supervisor.which_children(Gossip.Supervisor), fn child ->
            child_pid = Enum.at(Tuple.to_list(child), 1)
			{_neighbours, fact, _fact_counter, _sum, _weight, _state, _fact_monger, _monitor} = :sys.get_state(child_pid)
			IO.write(file, inspect(child_pid) <> ": Fact = " <> fact <> "\n")
		end)

	"pushsum" ->
		Enum.each(Supervisor.which_children(Gossip.Supervisor), fn child ->
            child_pid = Enum.at(Tuple.to_list(child), 1)
            {_neighbours, _fact, _fact_counter, sum, weight, _state, _fact_monger, _monitor} = :sys.get_state(child_pid)
			IO.write(file, inspect(child_pid) <> ": Sum Estimate = " <> inspect(sum/weight) <> "\n")
		end)

	_ -> nil
end
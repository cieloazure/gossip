usage_string = "Invalid arguments to the command\nUsage: mix run proj2.exs --no-halt <numNodes:int> <topology:string> <algorithm:string>"
if length(System.argv) != 3 do
   raise(ArgumentError, usage_string)
 end
[numNodes, topology, algorithm] = Enum.map(System.argv, fn x -> x end)
# Gossip.P2PSupervisor.start_children(Gossip.P2PSupervisor, String.to_integer(numNodes), topology, algorithm)
{time, {:ok, child_pids}} = :timer.tc(Gossip.P2PSupervisor, :start_children, [Gossip.P2PSupervisor, String.to_integer(numNodes), topology, algorithm])

IO.puts "\ntime = #{time/:math.pow(10, 3)} ms"

File.rm("node_states.txt")
{:ok, file} = File.open "node_states.txt", [:write]
IO.write(file, "#{numNodes} " <> topology <> " " <> algorithm)
IO.write(file, "Node States:\n")

case algorithm do
	"gossip" ->
		Enum.each(child_pids, fn pid ->
			state = :sys.get_state(pid)
			IO.write(file, inspect(pid) <> ": Fact = " <> inspect(Enum.at(Tuple.to_list(state), 1)) <> "\n")
		end)

	"pushsum" ->
		Enum.each(child_pids, fn pid ->
			state = :sys.get_state(pid)
			IO.write(file, inspect(pid) <> ": Sum Estimate = " <> inspect(Enum.at(Tuple.to_list(state), 4)/Enum.at(Tuple.to_list(state), 5)) <> "\n")
		end)

	_ -> nil
end
# {t, {:ok, child_pids}} = :timer.tc(Gossip.P2PSupervisor, :start_children, [Gossip.P2PSupervisor, String.to_integer(numNodes), topology, algorithm])
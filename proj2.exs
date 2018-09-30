usage_string = "Invalid arguments to the command\nUsage: mix run proj2.exs --no-halt <numNodes:int> <topology:string> <algorithm:string>"
if length(System.argv) != 3 do
   raise(ArgumentError, usage_string)
 end
[numNodes, topology, algorithm] = Enum.map(System.argv, fn x -> x end)
Gossip.P2PSupervisor.start_children(Gossip.P2PSupervisor, String.to_integer(numNodes), topology, algorithm)
# {t, {:ok, child_pids}} = :timer.tc(Gossip.P2PSupervisor, :start_children, [Gossip.P2PSupervisor, String.to_integer(numNodes), topology, algorithm])

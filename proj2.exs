usage_string = "Invalid arguments to the command\nUsage: mix run proj2.exs --no-halt <numNodes:int> <topology:string> <algorithm:string>"
if length(System.argv) != 3 do
   raise(ArgumentError, usage_string)
end
#TODO : Add error checking
[num_nodes, topology, algorithm]  = System.argv
{:ok, pid} = Gossip.ConvergenceMonitor.start_link([num_nodes: String.to_integer(num_nodes), topology: topology, algorithm: algorithm])
Gossip.ConvergenceMonitor.start_simulation(pid)

usage_string = "Invalid arguments to the command\nUsage: mix run proj2.exs --no-halt <numNodes:int> <topology:string> <algorithm:string>"
if length(System.argv) != 2 do
   raise(ArgumentError, usage_string)
end
#TODO : Add error checking
[num_nodes, topology]  = System.argv
Gossip.ConvergenceMonitor.start_link([num_nodes: String.to_integer(num_nodes), topology: topology])

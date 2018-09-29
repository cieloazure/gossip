usage_string = "Invalid arguments to the command\nUsage: mix run proj2.exs --no-halt <numNodes:int> <topology:string> <algorithm:string>"
try do
  if length(System.argv) != 3 do
    IO.puts "--------- #{length(System.argv)}"
    raise ArgumentError
  end
  [numNodes, topology, algorithm] = Enum.map(System.argv, fn x -> x end)
  Gossip.P2PSupervisor.start_children(Gossip.P2PSupervisor, String.to_integer(numNodes), topology, algorithm)
  # {t, {:ok, child_pids}} = :timer.tc(Gossip.P2PSupervisor, :start_children, [Gossip.P2PSupervisor, String.to_integer(numNodes), topology, algorithm])
rescue
  _e in ArgumentError -> IO.puts usage_string
end
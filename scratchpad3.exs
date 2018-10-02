require Logger
num_nodes = "10"
topology = "3d"
algorithm = "pushsum"

{:ok, monitor} = Gossip.ConvergenceMonitor.start_link([num_nodes: String.to_integer(num_nodes), topology: topology, algorithm: algorithm])
{:ok, child_pids} = Gossip.Supervisor.start_children(Gossip.Supervisor,String.to_integer(num_nodes), monitor)

pid = Enum.random(child_pids)
send(pid, {:pushsum, -1, -1, -1, nil})

values  = Enum.map(child_pids, fn child_pid -> 
  {_, sum, weight, _, _, _, _, _} = :sys.get_state(pid)
  {child_pid, sum / weight}
end)

IO.inspect values, [limit: :infinity]


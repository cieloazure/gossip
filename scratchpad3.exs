require Logger
num_nodes = "3"
topology = "full"
algorithm = "pushsum"

{:ok, monitor} = Gossip.ConvergenceMonitor.start_link([num_nodes: String.to_integer(num_nodes), topology: topology, algorithm: algorithm])
{:ok, child_pids} = Gossip.Supervisor.start_children(Gossip.Supervisor,String.to_integer(num_nodes), monitor)

pid = Enum.random(child_pids)
send(pid, {:pushsum, -1, -1, -1, nil})


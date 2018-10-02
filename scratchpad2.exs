{:ok, child_pids} = Gossip.P2PSupervisor.start_children(Gossip.P2PSupervisor, 10, "full")
pid = Enum.random(child_pids)
send(pid, {:fact, 42, -1, nil})


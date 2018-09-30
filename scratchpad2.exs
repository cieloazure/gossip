{:ok, child_pids} = Gossip.P2PSupervisor.start_children(Gossip.P2PSupervisor, 5)
 pid = Enum.random(child_pids)
  send(pid, {:fact, 42})

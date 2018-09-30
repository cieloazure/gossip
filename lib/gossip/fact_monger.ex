defmodule Gossip.FactMonger do
  def start(pid) do
    Gossip.Ticker.start pid, 3000  
  end

  def stop(pid) do
    Gossip.Ticker.stop pid
  end

  def run(neighbours, fact, ticker_pid) do
    receive do
      {:tick, _index} = message ->
        IO.inspect(message)
        IO.puts "Sending fact to one of neighbour: #{fact}"
        send(Enum.random(neighbours), {:fact, fact})
        run(neighbours, fact, ticker_pid)
      {:last_tick, _index} = message ->
        IO.inspect(message)
        IO.puts "Removing timer for fact monger and terminating fact mongering" 
        :ok
      {:fact, new_fact}  -> 
        IO.puts "Updating fact to #{new_fact} and periodically sending it to new neighbours"
        ticker_pid = if fact == -1 do
          start(self)
        else
          ticker_pid
        end
        run(neighbours, new_fact, ticker_pid)
      {:neighbours, new_neighbours} ->
        IO.puts "Updating neighbours list"
        run(new_neighbours, fact, ticker_pid)
      {:stop, _reason} -> 
        IO.puts "Got instruction to terminate spreading rumour"
        stop(ticker_pid)
        run(neighbours, fact, ticker_pid)
    end
  end
end

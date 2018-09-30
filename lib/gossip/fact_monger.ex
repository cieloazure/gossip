defmodule Gossip.FactMonger do
  @mongering_interval 5

  def start(pid) do
    Gossip.Ticker.start pid, @mongering_interval  
  end

  def stop(pid) do
    Gossip.Ticker.stop pid
  end

  def run(neighbours, fact, our_fact_counter, our_pid, ticker_pid) do
    receive do
      {:tick, _index} = message ->
        #IO.inspect(message)
        #IO.puts "Sending fact to one of neighbour: #{fact}"
        send(Enum.random(neighbours), {:fact, fact, our_fact_counter, our_pid})
        run(neighbours, fact, our_fact_counter, our_pid, ticker_pid)

      {:last_tick, _index} = message ->
        #IO.inspect(message)
        #IO.puts "Removing timer for fact monger and terminating fact mongering" 
        :ok

      {:fact, new_fact, new_fact_counter, our_new_pid}  -> 
        #IO.puts "Updating fact to #{new_fact_counter} and periodically sending it to new neighbours of #{inspect(our_new_pid)}"
        ticker_pid = if fact == -1 do
          start(self())
        else
          ticker_pid
        end
        run(neighbours, new_fact, new_fact_counter, our_new_pid, ticker_pid)

      {:neighbours, new_neighbours} ->
        #IO.puts "Updating neighbours list"
        run(new_neighbours, fact, our_fact_counter, our_pid, ticker_pid)

      {:stop, _reason} -> 
        #IO.puts "Got instruction to terminate spreading rumour"
        stop(ticker_pid)
        run(neighbours, fact, our_fact_counter, our_pid, ticker_pid)
    end
  end
end

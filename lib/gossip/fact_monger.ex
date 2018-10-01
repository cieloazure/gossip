defmodule Gossip.FactMonger do
  require Logger
  @mongering_interval 5

  def start(pid) do
    Gossip.Ticker.start(pid, @mongering_interval)
  end

  def stop(pid) do
    Gossip.Ticker.stop(pid)
  end

  def run(neighbours, fact, our_fact_counter, our_pid, ticker_pid) do
    receive do
      {:tick, _index} = message ->
        Logger.debug(inspect(message))
        Logger.debug(inspect(neighbours))
        Logger.debug("Sending fact to one of neighbour: #{fact}")
        if !is_nil(neighbours) and !Enum.empty?(neighbours), do: send(Enum.random(neighbours), {:fact, fact, our_fact_counter, our_pid})
        run(neighbours, fact, our_fact_counter, our_pid, ticker_pid)

      {:last_tick, _index} = message ->
        Logger.debug(inspect(message))
        Logger.debug("Removing timer for fact monger and terminating fact mongering")
        :ok

      {:fact, new_fact, new_fact_counter, our_new_pid} ->
        Logger.debug(
          "Updating fact to #{new_fact_counter} and periodically sending it to new neighbours of #{
            inspect(our_new_pid)
          }"
        )

        ticker_pid =
          if fact == -1 do
            start(self())
          else
            ticker_pid
          end

        run(neighbours, new_fact, new_fact_counter, our_new_pid, ticker_pid)

      {:neighbours, new_neighbours} ->
        Logger.debug("Updating neighbours list")
        neighbours = MapSet.union(new_neighbours, neighbours)
        Logger.debug(inspect(neighbours))
        run(neighbours, fact, our_fact_counter, our_pid, ticker_pid)

      {:stop, _reason} ->
        Logger.debug("Got instruction to terminate spreading rumour")
        stop(ticker_pid)
        run(neighbours, fact, our_fact_counter, our_pid, ticker_pid)
    end
  end
end

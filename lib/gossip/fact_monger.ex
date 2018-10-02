defmodule Gossip.FactMonger do
  #TODO: Change Name to Gossip.PeriodicDisseminator
  @moduledoc """
  This module is reponsible for disseminating periodic messages to the random neighbour of the node
  Each Node will have a sibling FactMonger process which will help in periodic spreading of message
  Periodic ticks are provided by Gossip.Ticker
  """
  require Logger
  @mongering_interval 10

  @doc """
  Start the ticker for the fact monger
  Will keep receiving tick events of the form `{:tick, _index}` at every `@mongering_interval` time
  """
  def start(pid) do
    Gossip.Ticker.start(pid, @mongering_interval)
  end

  @doc """
  Stop the ticker for the fact monger
  Will send a event of `{:last_tick, index}` to the fact monger
  """
  def stop(pid) do
    Gossip.Ticker.stop(pid)
  end

  @doc """
  Runner for Gossip algorithm
  Will run alongside `Gossip.NodeV2` for `gossip` algorithm
  """
  def run(neighbours, fact, our_fact_counter, our_pid, ticker_pid) do
    receive do
      {:tick, _index} = message ->
        Logger.debug(inspect(message))
        Logger.debug(inspect(neighbours))
        Logger.debug("Sending fact to one of neighbour: #{fact}")

        if !is_nil(neighbours) and !Enum.empty?(neighbours),
          do: send(Enum.random(neighbours), {:fact, fact, our_fact_counter, our_pid})

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

  @doc """
   Runner for pushsum algorithm
   Will run alongside `Gossip.NodeV3` for `pushsum` algorithm
  """
  def run(neighbours, our_sum, our_weight, our_round_counter, our_pid, ticker_pid) do
    Logger.debug("Starting fact monger")

    receive do
      {:tick, _index} = message ->
        Logger.debug(inspect(message))
        Logger.debug(inspect(neighbours))
        Logger.debug("Sending fact to one of neighbours of #{inspect(our_pid)}")

        if !is_nil(neighbours) and !Enum.empty?(neighbours) do
          # Send periodically to one of the neighbours
          send(
            Enum.random(neighbours),
            {:pushsum, our_sum / 2, our_weight / 2, our_round_counter, our_pid}
          )

          # Keep half of the sum and weight and update our own values
          send(our_pid, {:update_values, our_sum / 2, our_weight / 2})
        end

        run(neighbours, our_sum, our_weight, our_round_counter, our_pid, ticker_pid)

      {:last_tick, _index} = message ->
        Logger.debug(inspect(message))

        Logger.debug(
          "Removing timer for fact monger and terminating fact mongering for #{inspect(our_pid)}"
        )

        :ok

      {:new_sum_and_weight, new_sum, new_weight, new_round_counter, our_new_pid} ->
        Logger.debug(
          "Updating sum to #{new_sum} and weight to #{new_weight} for FactMonger and periodically sending it to new neighbours of #{
            inspect(our_new_pid)
          }"
        )

        ticker_pid =
          if is_nil(ticker_pid) do
            start(self())
          else
            ticker_pid
          end

        run(neighbours, new_sum, new_weight, new_round_counter, our_new_pid, ticker_pid)

      {:neighbours, new_neighbours} ->
        Logger.debug("Updating neighbours list")
        neighbours = MapSet.union(new_neighbours, neighbours)
        Logger.debug(inspect(neighbours))
        run(neighbours, our_sum, our_weight, our_round_counter, our_pid, ticker_pid)

      {:stop, _reason} ->
        Logger.debug("Got instruction to terminate spreading rumour")
        stop(ticker_pid)
        run(neighbours, our_sum, our_weight, our_round_counter, our_pid, ticker_pid)
    end
  end
end

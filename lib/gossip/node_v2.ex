defmodule Gossip.NodeV2 do
  use GenServer
  require Logger

  @susceptible "susceptible"
  @infected "infected"
  @removed "removed"
  @convergence_state_counter 10

  # Client
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def add_new_neighbours(pid, new_neighbours) do
    GenServer.cast(pid, {:add_new_neighbours, new_neighbours})
  end

  def add_new_neighbour(pid, new_neighbour) do
    new_neighbour = MapSet.new([new_neighbour])
    GenServer.cast(pid, {:add_new_neighbours, new_neighbour})
  end

  def add_new_neighbours_dual(pid, new_neighbours) do
    # IO.inspect(new_neighbours)
    add_new_neighbours(pid, new_neighbours)
    Enum.each(new_neighbours, fn new_neighbour -> add_new_neighbour(new_neighbour, pid) end)
  end

  def get_neighbours(pid) do
    GenServer.call(pid, {:get_neighbours})
  end

  # Server

  @impl true
  def init(opts) do
    neighbours = MapSet.new([])
    fact = -1
    fact_counter = 0
    sum = Keyword.get(opts, :node_number)
    weight = 1
    state = @susceptible
    fact_monger = spawn(Gossip.FactMonger, :run, [neighbours, fact, fact_counter, sum, weight, self(), nil])
    monitor = Keyword.get(opts, :monitor)
    {:ok, {neighbours, fact, fact_counter, sum, weight, state, fact_monger, monitor}}
  end

  @impl true
  def handle_cast(
        {:add_new_neighbours, new_neighbours},
        {neighbours, fact, fact_counter, sum, weight, state, fact_monger, monitor}
      ) do
    new_neighbours =
      if !is_map(new_neighbours), do: MapSet.new(new_neighbours), else: new_neighbours

    Logger.debug(inspect(new_neighbours))
    send(fact_monger, {:neighbours, new_neighbours})

    {:noreply,
     {MapSet.union(neighbours, new_neighbours), fact, fact_counter, sum, weight, state, fact_monger, monitor}}
  end

  @impl true
  def handle_info(
        {:fact, their_fact, their_fact_counter, their_pid},
        {neighbours, our_fact, our_fact_counter, sum, weight, _state, fact_monger, monitor}
      ) do
    # Received a fact
    # update the fact if hearing it for the first time

    # Request-Reply cycle for push-pull
    {resultant_fact, our_fact_counter} =
      if !is_nil(their_pid) do
        cond do
          their_fact_counter == our_fact_counter ->
            Logger.debug("Fact counter #{inspect(their_pid)} == #{inspect(self())}")
            {their_fact, our_fact_counter + 1}

          their_fact_counter > our_fact_counter ->
            Logger.debug("Fact counter #{inspect(their_pid)} > #{inspect(self())}")
            {their_fact, our_fact_counter + 1}

          their_fact_counter < our_fact_counter ->
            Logger.debug("Fact counter #{inspect(their_pid)} <  #{inspect(self())}")
            send(their_pid, {:fact, our_fact, our_fact_counter, self()})
            {our_fact, our_fact_counter}

          true ->
            {their_fact, their_fact_counter}
        end
      else
        Logger.debug("Received from supervisor")
        {their_fact, our_fact_counter + 1}
      end

    Logger.debug("Resultant fact is #{resultant_fact}")

    state =
      cond do
        our_fact_counter == 1 ->
          Logger.debug("Changed state to infected just now #{inspect(self())}")
          send(fact_monger, {:fact, resultant_fact, our_fact_counter, self()})
          @infected

        our_fact_counter > 1 and our_fact_counter < @convergence_state_counter ->
          Logger.debug("Not yet reached convergence #{inspect(self())}")
          send(fact_monger, {:fact, resultant_fact, our_fact_counter, self()})
          @infected

        our_fact_counter >= @convergence_state_counter ->
          Logger.debug("Reached convergence for #{inspect(self())}")

          if our_fact_counter == @convergence_state_counter do
            send(fact_monger, {:stop, 1})
            send(monitor, {:convergence_event, self()})
          end

          @removed

        true ->
          nil
      end

    {:noreply, {neighbours, resultant_fact, our_fact_counter, sum, weight, state, fact_monger, monitor}}
  end

  @impl true
  def handle_info(
    {:pushsum, their_sum, their_weight},
    {neighbours, _fact, our_fact_counter, sum, weight, _state, fact_monger, monitor}
  ) do

    resultant_sum = sum + their_sum
    resultant_weight = weight + their_weight
    # {resultant_sum, resultant_weight, fact_counter} = cond do
    #   their_fact_counter >= our_fact_counter ->
    #     {sum + their_sum, weight + their_weight, our_fact_counter + 1}

    #   their_fact_counter < our_fact_counter ->
    #     send(their_pid, {:pushsum, sum, weight, our_fact_counter, self()})
    #     {sum, weight, our_fact_counter}

    #   true ->
    #     {sum + their_sum, weight + their_weight, our_fact_counter + 1}
    # end

    sum_estimate_delta = resultant_sum/resultant_weight + sum/weight

    {state, resultant_sum, resultant_weight, fact_counter} = cond do
      sum_estimate_delta >= :math.pow(10, -10) ->
        send(fact_monger, {:pushsum, resultant_sum/2, resultant_weight/2})
        {@infected, resultant_sum/2, resultant_weight/2, our_fact_counter}

      sum_estimate_delta < :math.pow(10, -10) ->
        if our_fact_counter + 1 < 3 do
          send(fact_monger, {:pushsum, resultant_sum/2, resultant_weight/2})
          {@infected, resultant_sum/2, resultant_weight/2, our_fact_counter + 1}
        else
          send(fact_monger, {:stop, 1})
          send(monitor, {:convergence_event, self()})
          {@removed, resultant_sum, resultant_weight, our_fact_counter} 
        end
    
      true ->
        nil
    end

    {:noreply, {neighbours, 0, fact_counter, resultant_sum, resultant_weight, state, fact_monger, monitor}}
  end

  @impl true
  def handle_call(
        {:get_neighbours},
        _from,
        {neighbours, fact, fact_counter, sum, weight, state, fact_monger, monitor}
      ) do
    {:reply, neighbours, {neighbours, fact, fact_counter, sum, weight, state, fact_monger, monitor}}
  end
end

defmodule Gossip.NodeV3 do
  @moduledoc """
    A GenServer Node to handle the states of pushsum algorithm. Has state variables specific to pushsum algorithm
  """
  use GenServer
  require Logger

  @susceptible "susceptible"

  # Client API
  @doc """
    Starts the GenServer.NodeV3
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
    Adds multiple neighbours to this node 
  """
  def add_new_neighbours(pid, new_neighbours) do
    GenServer.cast(pid, {:add_new_neighbours, new_neighbours})
  end

  @doc """
    Adds a new neighbour to this node
  """
  def add_new_neighbour(pid, new_neighbour) do
    new_neighbour = MapSet.new([new_neighbour])
    GenServer.cast(pid, {:add_new_neighbours, new_neighbour})
  end

  @doc """
    Adds a new neighbour with a two way connection
  """
  def add_new_neighbours_dual(pid, new_neighbours) do
    add_new_neighbours(pid, new_neighbours)
    Enum.each(new_neighbours, fn new_neighbour -> add_new_neighbour(new_neighbour, pid) end)
  end

  @doc """
    Returns a list of neighbours for a node
  """
  def get_neighbours(pid) do
    GenServer.call(pid, {:get_neighbours})
  end

  # Server Callbacks
  
  @doc """
    Initiates the state of the Gossip.NodeV2
  """
  @impl true
  def init(opts) do
    neighbours = MapSet.new([])
    sum = Keyword.get(opts, :node_number)
    weight = 1
    round_counter = 0
    state = @susceptible

    fact_monger =
      spawn(Gossip.FactMonger, :run, [neighbours, sum, weight, round_counter, self(), nil])

    monitor = Keyword.get(opts, :monitor)
    most_recent_actors_ratio = [nil, nil]

    {:ok,
     {neighbours, sum, weight, round_counter, state, fact_monger, monitor,
      most_recent_actors_ratio}}
  end


  @doc """
    Callback to handle updating the values(state) for this node
  """
  @impl true
  def handle_info(
        {:update_values, new_sum, new_weight},
        {neighbours, _our_sum, _our_weight, our_round_counter, our_state, our_fact_monger,
         monitor, our_most_recent_actors_ratio}
      ) do
    # Update the state in fact monger
    send(our_fact_monger, {:new_sum_and_weight, new_sum, new_weight, our_round_counter, self()})

    # Update the state in genserver
    {:noreply,
     {neighbours, new_sum, new_weight, our_round_counter, our_state, our_fact_monger, monitor,
      our_most_recent_actors_ratio}}
  end

  @doc """
    Callback to handle the pushsum algorithm logic. Has the logic for sending periodic updates through fact monger and push-pull resoltion of nodes
  """
  @impl true
  def handle_info(
        {:pushsum, their_sum, their_weight, their_round_counter, their_pid},
        {neighbours, our_sum, our_weight, our_round_counter, our_state, our_fact_monger, monitor,
         our_most_recent_actors_ratio}
      ) do
    Logger.debug("Their pid #{inspect(their_pid)}")
    Logger.debug("our pid #{inspect(self())}")

    if is_nil(their_pid) do
      Logger.debug("Initiating pushsum in #{inspect(self())}")
      send(self(), {:update_values, our_sum, our_weight})

      {:noreply,
       {neighbours, our_sum, our_weight, our_round_counter, our_state, our_fact_monger, monitor,
        our_most_recent_actors_ratio}}
    else
      {our_sum, our_weight, our_round_counter} =
        cond do
          their_round_counter == our_round_counter ->
            our_round_counter = our_round_counter + 1
            our_sum = our_sum + their_sum
            our_weight = our_weight + their_weight
            {our_sum, our_weight, our_round_counter}

          their_round_counter > our_round_counter ->
            our_round_counter = our_round_counter + 1
            our_sum = our_sum + their_sum
            our_weight = our_weight + their_weight
            {our_sum, our_weight, our_round_counter}

          their_round_counter < our_round_counter ->
            send(their_pid, {:pushsum, our_sum / 2, our_weight / 2, our_round_counter, self()})
            {our_sum, our_weight, our_round_counter}

          true ->
            {their_sum, their_weight, their_round_counter}
        end

      new_ratio = our_sum / our_weight
      # Logger.debug(("sum in #{inspect(self())} is #{our_sum}"))
      # Logger.debug(("weight in #{inspect(self())} is #{our_weight}"))
      # Logger.debug( "New ratio for #{inspect(self())}is #{new_ratio}")
      # Logger.debug( "Previous ratios for #{inspect(self())} are #{inspect(our_most_recent_actors_ratio)}" )

      new_val =
        if Enum.member?(our_most_recent_actors_ratio, nil) do
          # Logger.debug( "Still some nil values present")
          new_ratio
        else
          if abs(List.last(our_most_recent_actors_ratio) - new_ratio) > :math.pow(10, -10) do
            # not reached convergence yet, put new_ratio in
            # most_recent_actors_ratio
            # Logger.debug( "Not reached convergence yet for #{inspect(self())}")
            new_ratio
          else
            if abs(List.first(our_most_recent_actors_ratio) - new_ratio) < :math.pow(10, -2) do
              # reached convergence, stop sending updates
              Logger.debug("Reached convergence for #{inspect(self())}")
              Logger.debug("-Estimate at #{inspect(self())}: #{inspect(new_ratio)}")
              send(our_fact_monger, {:stop, 1})
              send(monitor, {:convergence_event, self()})
              nil
            else
              # wait for one more cycle
              new_ratio
            end
          end
        end

      Logger.debug("Value to update mru with #{inspect(new_val)}")

      our_most_recent_actors_ratio =
        if !is_nil(new_val) do
          Logger.debug("a new ratio to put in mru")
          Logger.debug(our_round_counter)
          send(self(), {:update_values, our_sum, our_weight})

          # send(our_fact_monger, {:new_sum_and_weight, our_sum, our_weight, our_round_counter, self()})
          List.replace_at(our_most_recent_actors_ratio, rem(our_round_counter - 1, 2), new_val)
        else
          Logger.debug("Convergence reached. No new ratio to put in mru")

          our_ratio = our_sum / our_weight
          their_ratio = their_sum / their_weight
          Logger.debug(our_ratio)
          Logger.debug(their_ratio)

          if abs(our_ratio - their_ratio) > :math.pow(10, -2) do
            Logger.debug("Sending from Converged to non converged")
            send(their_pid, {:pushsum, our_sum / 2, our_weight / 2, our_round_counter, self()})
            send(self(), {:update_values, our_sum / 2, our_weight / 2})
          else
            Logger.debug("Not sending! Both have converged-")
          end

          our_most_recent_actors_ratio
        end

      Logger.debug("mru buffer: #{inspect(our_most_recent_actors_ratio)}")

      {:noreply,
       {neighbours, our_sum, our_weight, our_round_counter, our_state, our_fact_monger, monitor,
        our_most_recent_actors_ratio}}
    end
  end

  @doc """
    Callback to handle adding neighbours to the node
  """
  @impl true
  def handle_cast(
        {:add_new_neighbours, new_neighbours},
        {neighbours, sum, weight, round_counter, state, fact_monger, monitor,
         most_recent_actors_ratio}
      ) do
    new_neighbours =
      if !is_map(new_neighbours), do: MapSet.new(new_neighbours), else: new_neighbours

    Logger.debug(inspect(new_neighbours))
    send(fact_monger, {:neighbours, new_neighbours})

    {:noreply,
     {MapSet.union(neighbours, new_neighbours), sum, weight, round_counter, state, fact_monger,
      monitor, most_recent_actors_ratio}}
  end

  @doc """
    Callback to handle getting neighbours for this node
  """
  @impl true
  def handle_call(
        {:get_neighbours},
        _from,
        {neighbours, sum, weight, round_counter, state, fact_monger, monitor,
         most_recent_actors_ratio}
      ) do
    {:reply, neighbours,
     {neighbours, sum, weight, round_counter, state, fact_monger, monitor,
      most_recent_actors_ratio}}
  end
end

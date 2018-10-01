defmodule Gossip.Node do
  use GenServer

  @counter_limit 10
  @message_interval 2

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

    add_new_neighbours(pid, new_neighbours)
    # GenServer.cast(pid, {:add_new_neighbours, new_neighbours})
    Enum.each(new_neighbours, fn new_neighbour -> add_new_neighbour(new_neighbour, pid) end)
  end

  def get_neighbours(pid) do
    GenServer.call(pid, {:get_neighbours})
  end

  # Server (callbacks)

  @impl true
  def init(opts) do
    sum = Keyword.get(opts, :node_number)
    weight = 1
    fact = ""
    fact_counter = 0
    neighbours = MapSet.new([])
    {:ok, {neighbours, fact, fact_counter, sum, weight}}
  end

  @impl true
  @doc """
  Callback to handle messages of type '{:add_new_neighbours, new_neighbours}'

  Adds new_neighbours to the neighbours MapSet of the node.
  """
  def handle_cast({:add_new_neighbours, new_neighbours}, {neighbours, fact, fact_counter, sum, weight}) do
    new_neighbours = if !is_map(new_neighbours), do: MapSet.new(new_neighbours), else: new_neighbours
    {:noreply, {MapSet.union(neighbours,new_neighbours), fact, fact_counter, sum, weight}}
  end

  @doc """
  Callback to handle messages of the type '{:gossip, fact}'

  This Callback is responsible for receiving gossip messages and updating fact_counter.
  Also initiates message transmission if fact_counter == 1.
  """
  @impl true
  def handle_info({:gossip, their_fact, their_fact_counter, their_pid}, {neighbours, my_fact, my_fact_counter, sum, weight}) do
    
    fact = if !is_nil(their_fact) do
      cond do
        their_fact_counter >= my_fact_counter ->
          their_fact

        their_fact_counter < my_fact_counter ->
          send(their_pid, {:gossip, my_fact, my_fact_counter, self()})
          my_fact

        true ->
          their_fact
      end
    else
      their_fact
    end

    my_fact_counter = my_fact_counter + 1

    if my_fact_counter == 1 do
      send(Enum.random(neighbours), {:gossip, fact, my_fact_counter, self()})
      send(self(), {:gossip})
    end

    {:noreply, {neighbours, fact, my_fact_counter, sum, weight}}
  end

  @impl true
  def handle_info({:gossip}, {neighbours, fact, fact_counter, sum, weight}) do
    if fact_counter < @counter_limit do
      send(Enum.random(neighbours), {:gossip, fact, fact_counter, self()})
      send(self(), {:gossip})
    end
    {:noreply, {neighbours, fact, fact_counter, sum, weight}}
  end

  @doc """
  Callback to handle messages of the type '{:pushsum, sum, weight}'

  This callback accepts the pushsum messages, updates node's sum and weight, 
  and continues by transmitting pushsum message to a random neighbouring node.
  """
  @impl true
  def handle_info({:pushsum, s, w}, {neighbours, fact, fact_counter, sum, weight}) do
    new_sum = sum + s
    new_weight = weight + w
    sum_estimate_delta = new_sum/new_weight - sum/weight

    {new_sum, new_weight, counter} = cond do
      sum_estimate_delta >= :math.pow(10, -10) ->
        send(Enum.random(neighbours), {:pushsum, new_sum/2, new_weight/2})
        send(self(), {:pushsum})
        {new_sum/2, new_weight/2, fact_counter}

      sum_estimate_delta < :math.pow(10, -10) ->
        if fact_counter + 1 < 10 do
          send(Enum.random(neighbours), {:pushsum, new_sum/2, new_weight/2})
          send(self(), {:pushsum})
          {new_sum/2, new_weight/2, fact_counter + 1}
        else
          {new_sum, new_weight, fact_counter}
        end

      true ->
        nil
    end

    {:noreply, {neighbours, fact, counter, new_sum, new_weight}}
  end
  
  @doc """
  Callback to handle messages of the type '{:pushsum}'

  This Callback accepts the initial message for pushsum from the Supervisor.
  """
  @impl true
  def handle_info({:pushsum}, {neighbours, fact, fact_counter, sum, weight}) do
    # Process.sleep(@message_interval)
    send(Enum.random(neighbours), {:pushsum, sum/2, weight/2})
    send(self(), {:pushsum})
    {:noreply, {neighbours, fact, fact_counter, sum/2, weight/2}}
  end

  @impl true
  def handle_call({:get_neighbours}, _from, {neighbours, fact, fact_counter, sum, weight}) do
    {:reply, neighbours, {neighbours, fact, fact_counter, sum, weight}}
  end

end
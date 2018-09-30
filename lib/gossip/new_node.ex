defmodule Gossip.NewNode do
  use GenServer

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
    #IO.inspect(new_neighbours)
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
    state = @susceptible
    fact_monger = spawn(Gossip.FactMonger, :run, [neighbours, fact, fact_counter, self(), nil])
    monitor = Keyword.get(opts, :monitor)
    {:ok, {neighbours, fact, fact_counter, state, fact_monger, monitor}}
  end

  @impl true
  def handle_cast({:add_new_neighbours, new_neighbours}, {neighbours, fact, fact_counter, state, fact_monger, monitor}) do
    new_neighbours = if !is_map(new_neighbours), do: MapSet.new(new_neighbours), else: new_neighbours
    send(fact_monger, {:neighbours, new_neighbours})
    {:noreply, {MapSet.union(neighbours,new_neighbours), fact, fact_counter, state, fact_monger, monitor}}
  end

  @impl true
  def handle_info({:fact, their_fact, their_fact_counter, their_pid}, {neighbours, our_fact, our_fact_counter, _state, fact_monger, monitor}) do
    # Received a fact
    # update the fact if hearing it for the first time

    # Request-Reply cycle for push-pull
    resultant_fact = if !is_nil(their_pid)  do
       cond do
        their_fact_counter == our_fact_counter -> 
          #IO.puts "Fact counter #{inspect(their_pid)} == #{inspect(self())}"
           their_fact
        their_fact_counter > our_fact_counter ->
          #IO.puts "Fact counter #{inspect(their_pid)} > #{inspect(self())}"
           #send(their_pid, {:fact, their_fact, our_fact_counter, self()})
          their_fact
        their_fact_counter < our_fact_counter -> 
          #IO.puts "Fact counter #{inspect(their_pid)} <  #{inspect(self())}"
          send(their_pid, {:fact, our_fact, our_fact_counter, self()})
          our_fact
        true -> 
         their_fact
      end
    else
        #IO.puts "Received from supervisor"
        their_fact
    end

    #IO.puts "Resultant fact is #{resultant_fact}"

    # update the fact counter
    our_fact_counter = our_fact_counter + 1
    #IO.inspect our_fact_counter

    state = cond do

      our_fact_counter == 1 -> 
        #IO.puts "Changed state to infected just now #{inspect(self())}"
        send(fact_monger, {:fact, resultant_fact, our_fact_counter, self()})
        @infected

      our_fact_counter > 1 and our_fact_counter < @convergence_state_counter ->
        #IO.puts "Not yet reached convergence #{inspect(self())}"
        send(fact_monger, {:fact, resultant_fact, our_fact_counter, self()})
        @infected

      our_fact_counter >= @convergence_state_counter -> 
        #IO.puts "Reached convergence for #{inspect(self())}"
        if our_fact_counter == @convergence_state_counter do
          send(fact_monger, {:stop, 1})
          send(monitor, {:convergence_event, self()})
        end
        @removed

      true -> 
        nil
    end

    {:noreply, {neighbours, resultant_fact, our_fact_counter, state, fact_monger, monitor}}
  end
end

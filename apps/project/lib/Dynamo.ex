defmodule Dynamo do
  @moduledoc """
  An implementation of the Dynamo consensus protocol.
  """
  # Shouldn't need to spawn anything from this module, but if you do
  # you should add spawn to the imports.
  import Emulation, only: [send: 2, timer: 1, now: 0, whoami: 0]

  import Kernel,
    except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]

  require Fuzzers
  # This allows you to use Elixir's loggers
  # for messages. See
  # https://timber.io/blog/the-ultimate-guide-to-logging-in-elixir/
  # if you are interested in this. Note we currently purge all logs
  # below Info
  require Logger

  # This structure contains all the process state
  # required by the Dynamo protocol.
  defstruct(
    # The list of current proceses.
    view: nil,
    # Current leader.
    store: nil
  )

  @doc """
  Create state for an initial Dynamo cluster. Each
  process should get an appropriately updated versi
  of this state.
  """
 
  def new_configuration(
        view,
        store
      ) do
    %Dynamo{
      view: view,
      store: Map.new()
    }
  end

  # Combine a single component in a vector clock.
  @spec combine_component(
          non_neg_integer(),
          non_neg_integer()
        ) :: non_neg_integer()
  defp combine_component(current, received) do
    if current > received do
      current 
    else 
      received
    end
  end

  @doc """
  Combine vector clocks: this is called whenever a
  message is received, and should return the clock
  from combining the two.
  """
  @spec combine_vector_clocks(map(), map()) :: map()
  def combine_vector_clocks(current, received) do
    # Map.merge just calls the function for any two components that
    # appear in both maps. Anything occuring in only one of the two
    # maps is just copied over. You should convince yourself that this
    # is the correct thing to do here.
    Map.merge(current, received, fn _k, c, r -> combine_component(c, r) end)
  end

  @doc """
  This function is called by the process `proc` whenever an
  event occurs, which for our purposes means whenever a message
  is received or sent.
  """
  @spec update_vector_clock(atom(), map()) :: map()
  def update_vector_clock(proc, clock) do
    Map.update!(clock, proc, fn existing_value -> existing_value + 1 end)
  end

  # Produce a new vector clock that is a copy of v1,
  # except for any keys (processes) that appear only
  # in v2, which we add with a 0 value. This function
  # is useful in making it so all process IDs do not
  # need to be known a-priori. YOU DO NOT NEED TO DIG
  # INTO THIS CODE, nor understand it.
  @spec make_vectors_equal_length(map(), map()) :: map()
  defp make_vectors_equal_length(v1, v2) do
    v1_add = for {k, _} <- v2, !Map.has_key?(v1, k), do: {k, 0}
    Map.merge(v1, Enum.into(v1_add, %{}))
  end

  # Compare two components of a vector clock c1 and c2.
  # Return @before if a vector of the form [c1] happens before [c2].
  # Return @after if a vector of the form [c2] happens before [c1].
  # Return @concurrent if neither of the above two are true.
  @spec compare_component(
          non_neg_integer(),
          non_neg_integer()
        ) :: :before | :after | :concurrent
  def compare_component(c1, c2) do
    cond do
      c1 < c2 -> :before
      c1 > c2 -> :after
      c1 = c2 -> :concurrent
    end
  end

  @doc """
  Compare two vector clocks v1 and v2.
  Returns @before if v1 happened before v2.
  Returns @hafter if v2 happened before v1.
  Returns @concurrent if neither of the above hold.
  """
  @spec compare_vectors(map(), map()) :: :before | :after | :concurrent
  def compare_vectors(v1, v2) do
    # First make the vectors equal length.
    v1 = make_vectors_equal_length(v1, v2)
    v2 = make_vectors_equal_length(v2, v1)
    # `compare_result` is a list of elements from
    # calling `compare_component` on each component of
    # `v1` and `v2`. Given this list you need to figure
    # out whether
    compare_result =
      Map.values(
        Map.merge(v1, v2, fn _k, c1, c2 -> compare_component(c1, c2) end)
      )
    a = Enum.all?(compare_result, fn x -> x == :before or x == :concurrent end)
    b = Enum.any?(compare_result, fn x -> x == :before end)
    c = Enum.all?(compare_result, fn x -> x == :after or x == :concurrent end)
    d = Enum.any?(compare_result, fn x -> x == :after end)
    e = Enum.all?(compare_result, fn x -> x == :concurrent end)
    cond do 
      a and b -> :before
      c and d -> :after
      b and d or e -> :concurrent
    end
  end

  # Insert the new value in store. First check for concurrency 
  def insert_in_store(state, key, value) do
    existing_values = state.store.key
    current_vc = value.vc
    concurrent_vals = Enum.filter(existing_values, fn x -> if compare_vectors(x.vc, current_vc) == :concurrent do x  end end)
    concurrent_vals = [value] ++  concurrent_vals
    %{state | store: Map.put(state.store, key, concurrent_vals)}
  end
 
  def get_from_store(state, key) do
    # list of Values will be returned. [%Value{value: a, vc: [..]}, %Value{value: b, vc: [..]}]
     Map.get(state.store, key)
  end

  @doc """
  """
  def update_store(state, entry) do
    case entry do
      {sender, {:set, client, key, value}} ->
        {{client, :ok}, insert_in_store(state,key,value)}

      {sender, {:get, client, key}} ->
        {client, get_from_store(state,key)}

      _ ->
        raise "Attempted to get not in store."
    end
  end

 

  @doc """
  make_leader changes process state for a process that
  has just been elected leader.
  """
 
  def make_coordinator(state) do
  
    %{
      state
      | is_coordinator: true,
        current_coordinator: whoami()
    }
  end

  
  def broadcast_to_others(state, message) do
    me = whoami()

    state.view
    |> Enum.filter(fn pid -> pid != me end)
    |> Enum.map(fn pid -> send(pid, message) end)
  end

  @doc """
  make_follower changes process state for a process
  to mark it as a follower.
  """
  
  def make_replica(state) do
    %{state | is_coordinator: false}
  end




  @doc """
  This function transitions a process so it is
  a follower.
  """
  def add_replica(state) do
    
    replica(make_replica(state))
  end

  @doc """
  This function implements the state machine for a process
  that is currently a follower.

  `extra_state` can be used to hod anything that you find convenient
  when building your implementation.
  """

  def replica(state) do
    receive do
      {sender,entry} ->
        update_store(state,entry)
        replica(state)
      end
  end

  @doc """
  This function transitions a process that is not currently
  the leader so it is a leader.
  """

  def become_coordinator(state) do
       
    coordinator(make_coordinator(state),%{version_num: 0,count: 0})
  end

  
  

  @doc """
  This function implements the state machine for a process
  that is currently the leader.

  `extra_state` can be used to hold any additional information.
  HINT: It might be useful to track the number of responses
  received for each AppendEntry request.
  """

  def coordinator(state,extra_state) do

    receive do
      {sender,{:get,key}} ->
        update_store(state,{:get,key})
        broadcast_to_others(state,{:get,sender,key})
        coordinator(state,extra_state)

      {sender,{:set,key,value}} ->
        
        update_store(state,{:set,key,value})
        broadcast_to_others(state,{:set,sender,key,value})
        coordinator(state,extra_state)

      {sender,{{r,:ok},state}} ->
        len = floor(Enum.count(state.view) / 2)
          
         
           send(r,:ok)
           
            coordinator(state,extra_state)
         
         coordinator(state,extra_state)


      {sender,{r,{ret,seqnumber}}} ->
        len = floor(Enum.count(state.view) / 2)
        
           send(r,ret)
           
           coordinator(state,extra_state)
          
          coordinator(state,extra_state)
        

    end
  end

  
end
defmodule Dynamo.Client do
  import Emulation, only: [send: 2]

  import Kernel,
    except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]

  @moduledoc """
  A client that can be used to connect and send
  requests to the RSM.
  """
  alias __MODULE__
  @enforce_keys [:coordinator]
  defstruct(coordinator: nil)

  @doc """
  Construct a new Dynamo Client. This takes an ID of
  any process that is in the RSM. We rely on
  redirect messages to find the correct leader.
  """
  @spec new_client(atom()) :: %Client{coordinator: atom()}
  def new_client(member) do
    %Client{coordinator: member}
  end

  

  @doc """
  Send a dequeue request to the RSM.
  """
  
  def get(client) do
    coordinator = client.coordinator
    send(coordinator, :get)

    receive do

      {_, v} ->
        {v, client}
    end
  end


  
  def put(client,key,value) do
    coordinator = client.coordinator
    send(coordinator, {:put,key,value})

    receive do
      {_, :ok} ->
        {:ok, client}
    end
  end
end

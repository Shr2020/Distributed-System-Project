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
    current_coordinator: nil,
    is_coordinator: nil,
    
    store: nil
  )

  @doc """
  Create state for an initial Dynamo cluster. Each
  process should get an appropriately updated version
  of this state.
  """
 
  def new_configuration(
        view,
        current_coordinator,
        is_coordinator,
        store
      ) do
    %Dynamo{
      view: view,
      current_coordinator: current_coordinator,
      is_coordinator: false,
      store: Map.new()
    }
  end

  # Enqueue an item, this **modifies** the state
  # machine, and should only be called when a log
  # entry is committed.
  
  def insert_in_store(state,key,value) do
    %{state | store: Map.put(state.store,key,{value,index})}
  end

  # Dequeue an item, modifying the state machine.
  # This function should only be called once a
  # log entry has been committed.
 
  def get_from_store(state,key) do
    {ret,seqnumber} = Map.get(state.store,key)
    {ret,seqnumber}
  end

  @doc """
  Commit a log entry, advancing the state machine. This
  function returns a tuple:
  * The first element is {requester, return value}. Your
    implementation should ensure that the leader who committed
    the log entry sends the return value to the requester.
  * The second element is the updated state.
  """
  
  def update_store(state, entry) do
    case entry do

      {sender,{:set,key,value,index}} ->
        {{r,index, :ok}, insert_in_store(state,key,value)}

      {sender,{:get,key,index}} ->
        {ret, state} = get_from_store(state,key)
        {{r,index, {ret,seqnumber}}


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
        version_num = version_num+1
        update_store(state,{:get,key,version_num})
        extra_state = Map.put(extra_state.index,version_num,0)
        broadcast_to_others(state,{r,:get,key,version_num})
        coordinator(state,extra_state)

      {sender,{:set,key,value}} ->
        version_num = version_num+1
        update_store(state,{:set,key,value,version_num})
        broadcast_to_others(state,{r,:set,key,value,version_num})
        coordinator(state,extra_state)

      {sender,{{r,version_num, :ok},state}} ->
        len = floor(Enum.count(state.view) / 2)
        %{extra_state | count: count+1}
         if(extra_state.count>=len) do
           send(r,:ok)
            %{extra_state | count: 0}
            coordinator(state,extra_state)
         end
         coordinator(state,extra_state)


      {sender,{r,version_num,{ret,seqnumber}}} ->
        len = floor(Enum.count(state.view) / 2)
        %{extra_state | count: count+1}
        if(extra_state.index<seqnumber) do
          if(extra_state.count>=len) do
           send(r,ret)
           %{extra_state | count: 0}
           coordinator(state,extra_state)
          end
          coordinator(state,extra_state)
        end
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


  
  def put(client, item) do
    coordinator = client.coordinator
    send(coordinator, {:put,key,value})

    receive do
      {_, :ok} ->
        {:ok, client}
    end
  end
end

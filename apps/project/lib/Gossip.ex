defmodule Gossip do
  @moduledoc """
  An implementation of the Raft consensus protocol.
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
  # required by the Raft protocol.
  defstruct(
    view: nil,
    roundTrip_timeout: 0,
    minProtocol_timeout: 0,
    pr: 0,
    roundTrip_timer: nil,
    minProtocol_timer: 0,
    ping_neighbour: nil
   
  )
 @doc """
  Create state for an initial Dynamo cluster. Each
  process should get an appropriately updated version
  of this state.
  """
 
  def new_configuration(
        view,
         roundTrip_timeout,
    minProtocol_timeout
      ) do
    %Gossip{
      view: view,
      roundTrip_timeout: roundTrip_timeout,
      minProtocol_timeout: minProtocol_timeout
    }
  end

  def getRandomNeighbour(state) do
    ping_neighbour = Enum.random(state.view)
    state = %{state | pr: state.pr+1,ping_neighbour: ping_neighbour}
    send(ping_neighbour,{:ping,state.pr})
    timer= Emulation.timer(state.roundTrip_timeout)
    failure_detection(state,state.pr)
    %{state | roundTrip_timer: timer}
  end


  def failure_detection(state,count) do

    receive do

     :timer -> 
        k_list = Enum.take_random(state.view, 2)
        %{state | minProtocol_timer: state.minProtocol_timeout-state.roundTrip_timeout}
        broadcast_to_others(k_list, {:pingreq,self(),state.ping_neighbour,count})
        failure_detection(state,count)

     {sender, {:ack,ping_neighbour,count}} -> 
      Emulation.cancel_timer(state.roundTrip_timer)
       broadcast_to_others(state.view,{ping_neighbour,:alive})
       if(!Enum.member?(state.view, ping_neighbour)) do
        state = %{state | view: [state.view | ping_neighbour]}
      end
      
      after 
        state.minProtocol_timer ->
        broadcast_to_others(state.view,{state.ping_neighbour,:failed})
        if(Enum.member?(state.view, node)) do
          state = %{state | view: List.delete(state.view, node)}
        end
      end

  end

  def receiver(state,count) do

  receive do

  {sender,{:ping,count}} -> 
        send(sender,{:ack,count})
        receiver(state,count)

      {sender,{node,:alive}} ->
      if(!Enum.member?(state.view, node)) do
        state = %{state | view: [state.view | node]}
        receiver(state,count)
      else
        receiver(state,count)
      end


      {sender, {:pingreq,pinger,ping_neighbour,count}} ->
        send(ping_neighbour,{:indirectping,ping_neighbour,pinger,count})
        receiver(state,count)
      
      {sender, {:indirectping,ping_neighbour,pinger,count}} ->
        send(sender,{:indirectack,ping_neighbour,pinger,count})
        receiver(state,count)

      
      {sender, {:indirectack,ping_neighbour,pinger,count}} ->
        send(pinger,{:ack,count})
        receiver(state,count)

      {sender,{node,:failed}} ->
      if(Enum.member?(state.view, node)) do
        state = %{state | view: List.delete(state.view, node)}
        receiver(state,count)
      else
        receiver(state,count)
      end

      {sender,{node,:joinreq}} ->
        broadcast_to_others(state.view,{node,:joined})
        if(!Enum.member?(state.view, node)) do
        state = %{state | view: [state.view | node]}
        receiver(state,count)
      else
        receiver(state,count)
      end
      {sender,{node,:joined}} ->
        if(!Enum.member?(state.view, node)) do
        state = %{state | view: [state.view | node]}
        receiver(state,count)
      else
        receiver(state,count)
      end
      
    end


  end
  
  
  def broadcast_to_others(list, message) do
    me = whoami()

    list
    |> Enum.filter(fn pid -> pid != me end)
    |> Enum.map(fn pid -> send(pid, message) end)
  end

end

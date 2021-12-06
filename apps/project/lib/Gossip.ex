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


  def getRandomNeighbour(state) do
    ping_neighbour = state.view |> Enum.filter(fn pid -> pid != whoami() end) |> Enum.random()
    state = %{state | pr: state.pr+1,ping_neighbour: ping_neighbour}
    send(ping_neighbour,{:ping,state.pr})
    rt_timer= Emulation.timer(state.roundTrip_timeout,:RT)
    mpt_timer= Emulation.timer(state.minProtocol_timeout,:MPT)
    %{state | roundTrip_timer: rt_timer,minProtocol_timer: mpt_timer}
   
  end


end

defmodule Client do
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
  
  def new_client(member) do
    %Client{coordinator: member}
  end

  

  @doc """
  Send a dequeue request to the RSM.
  """
  
  def get(client,key) do
    coordinator = client.coordinator
    send(coordinator, {:get,key})

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
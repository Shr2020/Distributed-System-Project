defmodule Dynamo.Client do
  import Emulation, only: [send: 2]

  import Kernel,
    except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]

  @moduledoc """
  A client that can be used to connect and send
  requests to the RSM.
  """
  alias __MODULE__
  @enforce_keys [:client]
  defstruct(
    client: nil,
    replica: nil
    )

  @doc """
  Construct a new Raft Client. This takes an ID of
  any process that is in the RSM. We rely on
  redirect messages to find the correct leader.
  """
 
  def new_client(member) do
    %Client{client: member}
  end

  
  @doc """
  Send a dequeue request to the RSM.
  """

  def get(client,replica,key) do

    send(replica,{:get,key})

    # receive do
    #   {sender, v} ->
    #     {v, client}
    # end
  end

  def set(client,replica,key,value) do

    send(replica,{:set,key,value})

    # receive do

    #   {sender, :ok} ->
    #     {:ok, client}
    # end
  end
end


defmodule ReplicationRequest do
  alias __MODULE__
  defstruct(
    key: nil,
    value: nil,
    reqnum: nil,
    op: nil
  )

  def new(k, v, reqnum,oper) do
    %ReplicationRequest{key: k, value: v, reqnum: reqnum,op: oper}
  end
end

defmodule ReplicationResponse do
  alias __MODULE__
  defstruct(
    key: nil,
    value: nil,
    reqnum: nil,
    op: nil
  )

  def new(k, val, reqnum, oper) do
    %ReplicationResponse{key: k, value: val,reqnum: reqnum, op: oper}
  end
end
defmodule MerkleSynchroRequest do
  alias __MODULE__
  defstruct(
    version: nil,
    merkle_chain: nil,
    match_entries: nil
  )

  def new(ver, chain, entries) do
    %MerkleSynchroRequest{version: ver, merkle_chain: chain, match_entries: entries}
  end
end

defmodule MerkleSynchroResponse do
  alias __MODULE__
  defstruct(
    version: nil,
    matched_hashes: nil,
    success: nil
  )

  def new(ver, hashes, success) do
    %MerkleSynchroResponse{version: ver, matched_hashes: hashes, success: success}
  end
end




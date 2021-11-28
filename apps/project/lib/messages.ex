defmodule Dynamo.Message do
  @moduledoc """
  Log entry for Raft implementation.
  """
  alias __MODULE__
  @enforce_keys [:index]
  defstruct(
    index: nil,
    operation: nil,
    requester: nil,
    argument: nil
  )
  
  def put(index, term, requester, item) do
    %Message{
      index: index,
      requester: requester,
      operation: :set,
      argument: item
    }
  end


  def get(index,key,requester) do
    %Message{
      index: index,
      requester: requester,
      operation: :get,
      argument: key
    }
  end
end

defmodule MerkleSynchroRequest do
  alias __MODULE__
  defstruct(
    merkle_chain: nil
    match_entries: nil
  )

  def new(chain, entries) do
    %MerkleSynchroRequest{merkle_chain: chain, match_entries: entries}
  end
end

defmodule MerkleSynchroResponse do
  alias __MODULE__
  defstruct(
    matched_hashes: nil
    success: nil
  )

  def new(hashes, success) do
    %MerkleSynchroResponse{matched_hashes: hashes, success: success}
  end
end


defmodule ReplicationRequest do
  alias __MODULE__
  defstruct(
    key: nil
    value: nil
    op: nil
  )

  def new(k, v, oper) do
    %ReplicationRequest{key: k, value: v, op: oper}
  end
end

defmodule ReplicationResponse do
  alias __MODULE__
  defstruct(
    key: nil
    success: nil
    op: nil
  )

  def new(k, succ, oper) do
    %ReplicationRequest{key: k, success: succ, op: oper}
  end
end




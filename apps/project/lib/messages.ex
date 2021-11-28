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




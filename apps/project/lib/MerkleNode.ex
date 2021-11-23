defmodule MerkleNode do
  alias __MODULE__
  defstruct(
    value: nil
  )

  @type hash :: binary() | String.t()

  @spec new(hash) :: %MerkleNode{}
  def new(val) do
    %MerkleNode{value: val}
  end
end
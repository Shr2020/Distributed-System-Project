defmodule MerkeTreeNode do
  alias __MODULE__
  defstruct(
    value: nil,
    left: nil
    right: nil
  )

  @type hash :: binary() | String.t()

  @spec new(hash) :: %MerkeTreeNode{}
  def new(value) do
    %MerkeTreeNode{value: value, left: nil, right: nil}
  end
end
defmodule MerkeNode do
  alias __MODULE__
  defstruct(
    value: nil
  )

  @type hash :: binary() | String.t()

  @spec new(hash) :: %MerkeNode{}
  def new(value) do
    %MerkeNode{value: value}
  end
end
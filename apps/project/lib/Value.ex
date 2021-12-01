defmodule Value do
  alias __MODULE__
  defstruct(val: nil,vc: nil)

  @spec new(any(), map()) :: %Value{}
  def new(v, vclck) do
    %Value{val: v, vc: vclck}
  end
end

# key value store will have key:[Value] 
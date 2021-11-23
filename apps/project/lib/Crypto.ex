defmodule Crypto do
  @moduledoc """
    This module defines some cryptographic hash functions used to hash block
    contents.
  """
  @spec sha256(any()) :: String.t()
  def sha256(data) do
    hash(:erlang.term_to_binary(data), :sha256)
  end

  @spec hash(String.t(), algorithm) :: String.t()
  def hash(data, algorithm) do
    :crypto.hash(algorithm, data) |> Base.encode16(case: :lower)
  end
end
defmodule Crypto do
  @moduledoc """
    This module defines some cryptographic hash functions used to hash block
    contents.
  """
  @spec sha256(String.t()) :: String.t()
  def sha256(data) do
    hash(data, :sha256)
  end
end
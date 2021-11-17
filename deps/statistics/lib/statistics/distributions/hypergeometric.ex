defmodule Statistics.Distributions.Hypergeometric do
  @moduledoc """
  Hypergeometric distribution.

  It models the probability that an n numbers of trials
  result in exactly k successes, with a population of pn items,
  where pk are considered as successes.
  """

  alias Statistics.Math

  @doc """
  The probability mass function
  ## Examples
      iex> Statistics.Distributions.Hypergeometric.pmf(50, 5, 10).(4)
      0.003964583058015066
  """
  @spec pmf(non_neg_integer, non_neg_integer, non_neg_integer) :: fun
  def pmf(pn, pk, n) do
    combos = Math.combination(pn, n)

    fn k ->
      cond do
        n < k ->
          0.0

        pn < n ->
          0.0

        pn == pk && n != k ->
          0.0

        pn == pk ->
          1.0

        true ->
          xk = Math.to_int(k)
          Math.combination(pk, xk) * Math.combination(pn - pk, n - xk) / combos
      end
    end
  end

  @doc """
  The cumulative density function
  ## Examples
      iex> Statistics.Distributions.Hypergeometric.cdf(52, 5, 13).(2)
      0.9072328931572629
  """
  @spec cdf(non_neg_integer, non_neg_integer, non_neg_integer) :: fun
  def cdf(pn, pk, n) do
    cpmf = pmf(pn, pk, n)

    fn k ->
      0..Math.to_int(Math.floor(k))
      |> Enum.to_list()
      |> Enum.map(fn i -> cpmf.(i) end)
      |> Enum.sum()
    end
  end

  @doc """
  The percentile-point function
  ## Examples
      iex> Statistics.Distributions.Hypergeometric.ppf(80, 20, 50).(0.1)
      10
  """
  @spec ppf(non_neg_integer, non_neg_integer, non_neg_integer) :: fun
  def ppf(pn, pk, n) do
    fn x ->
      ppf_tande(x, cdf(pn, pk, n), 0)
    end
  end

  # trial-and-error method which refines guesses
  # to arbitrary number of decimal places

  defp ppf_tande(x, tcdf, guess) do
    g_cdf = tcdf.(guess)

    cond do
      x > g_cdf ->
        ppf_tande(x, tcdf, guess + 1)

      x <= g_cdf ->
        guess
    end
  end

  @doc """
  Draw a random number from hypergeometric distribution
  """
  @spec rand(non_neg_integer, non_neg_integer, non_neg_integer) :: non_neg_integer
  def rand(pn, pk, n), do: rand(pk, pmf(pn, pk, n))

  defp rand(pk, rpmf) do
    x = Math.floor(Math.rand() * pk)

    if rpmf.(x) > Math.rand() do
      Float.round(x)
    else
      # keep trying
      rand(pk, rpmf)
    end
  end
end

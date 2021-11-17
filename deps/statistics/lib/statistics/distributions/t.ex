defmodule Statistics.Distributions.T do
  alias Statistics.Math
  alias Statistics.Math.Functions

  @moduledoc """
  Student's t distribution.

  This distribution is always centered around 0.0 and allows a *degrees of freedom* parameter.
  """

  @doc """
  The probability density function

  ## Examples

      iex> Statistics.Distributions.T.pdf(3).(0)
      0.3675525969478612
      iex> Statistics.Distributions.T.pdf(1).(3.2)
      0.028319384891796327

  """
  @spec pdf(number) :: fun
  def pdf(df) do
    fac = Functions.gamma((df + 1) / 2) / (Math.sqrt(df * Math.pi()) * Functions.gamma(df / 2))
    exp = (df + 1) / 2 * -1

    fn x -> fac * Math.pow(1 + x * x / df, exp) end
  end

  @doc """
  The cumulative density function

  NOTE: this currently uses the very slow Simpson's Rule to execute
  a numerical integration of the `pdf` function to approximate
  the CDF. This leads to a trade-off between precision and speed.

  A robust implementation of the 2F1 hypergeometric function is
  required to properly calculate the CDF of the t distribution.

  ## Examples

      iex> Statistics.Distributions.T.cdf(3).(0)
      0.4909182507070275
      
  """
  @spec cdf(number) :: fun
  def cdf(df) do
    cpdf = pdf(df)
    fn x -> Functions.simpson(cpdf, -10000, x, 10000) end
  end

  # when a robust hyp2F1 materialises, use this implementation
  # defp cdf_hyp2f1(x, df) do
  #  p1 = 0.5 + x * Functions.gamma((df+1)/2)
  #  p2n = Math.hyp2f1(0.5, ((df+1)/2), 1.5, -1*Math.pow(x,2)/df)
  #  p2d = Math.sqrt(Math.pi*df) * Functions.gamma(df/2)
  #  p1 * (p2n / p2d)
  # end

  @doc """
  The percentile-point function

  NOTE: this is very slow due to the current implementation of the CDF

  """
  @spec ppf(number) :: fun
  def ppf(df) do
    fn x ->
      ppf_tande(x, cdf(df), 4)
    end
  end

  # trial-and-error method which refines guesses
  # to arbitrary number of decimal places
  defp ppf_tande(x, pcdf, precision) do
    ppf_tande(x, pcdf, -10, precision + 2, 0)
  end

  defp ppf_tande(_, _, g, precision, precision) do
    g
  end

  defp ppf_tande(x, pcdf, g, precision, p) do
    increment = 100 / Math.pow(10, p)
    guess = g + increment

    if x < pcdf.(guess) do
      ppf_tande(x, pcdf, g, precision, p + 1)
    else
      ppf_tande(x, pcdf, guess, precision, p)
    end
  end

  @doc """
  Draw a random number from a t distribution with specified degrees of freedom
  """
  @spec rand(number) :: number
  def rand(df), do: randf(pdf(df))

  defp randf(rpdf) do
    # t-dist is fatter-tailed than normal
    x = Math.rand() * 50 - 25

    if rpdf.(x) > Math.rand() do
      x
    else
      # keep trying
      randf(rpdf)
    end
  end
end

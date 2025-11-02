defmodule Bitbase.PriceHistory do
  @moduledoc """
  Fetches historical BTC price from CoinGecko with rate limit handling.
  Like Spring @Service + @Retryable.
  """

  @base "https://api.coingecko.com/api/v3/coins/bitcoin/market_chart"

  @spec fetch(String.t()) :: {:ok, list()} | {:error, any()}
  def fetch("1D"), do: fetch_market_chart("1")
  def fetch("1W"), do: fetch_market_chart("7")
  def fetch("1M"), do: fetch_market_chart("30")
  def fetch("YTD"), do: fetch_range_ytd()
  def fetch("1Y"), do: fetch_range_1y()
  def fetch(_), do: fetch_market_chart("1")

  defp fetch_market_chart(days) do
    url = "#{@base}?vs_currency=usd&days=#{days}"
    fetch_and_parse(url)
  end

  defp fetch_range_ytd do
    today = Date.utc_today()
    from = Date.new!(today.year, 1, 1)
    fetch_range(Date.to_string(from), Date.to_string(today))
  end

  defp fetch_range_1y do
    to = Date.utc_today()
    from = Date.add(to, -365)
    fetch_range(Date.to_string(from), Date.to_string(to))
  end

  defp fetch_range(from_str, to_str) do
    from_date = Date.from_iso8601!(from_str)
    to_date = Date.from_iso8601!(to_str)

    from_unix = DateTime.new!(from_date, ~T[00:00:00]) |> DateTime.to_unix()
    to_unix = DateTime.new!(to_date, ~T[23:59:59]) |> DateTime.to_unix()

    url =
      "https://api.coingecko.com/api/v3/coins/bitcoin/market_chart/range?vs_currency=usd&from=#{from_unix}&to=#{to_unix}"

    fetch_and_parse(url)
  end

  defp fetch_and_parse(url) do
    case HTTPoison.get(url, [], timeout: 15_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"prices" => prices}} when prices != [] ->
            {:ok, Enum.take(prices, -100)}

          _ ->
            {:error, :no_data}
        end

      {:ok, %HTTPoison.Response{status_code: 429}} ->
        # Rate limit — wait 60s before retry (from Retry-After header)
        Process.sleep(60_000)
        # Retry
        fetch_and_parse(url)

      {:error, reason} ->
        {:error, reason}
    end
  end
end

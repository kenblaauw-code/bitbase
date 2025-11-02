defmodule Bitbase.BitcoinPrice do
  @moduledoc """
  Fetches live BTC/USD from CoinGecko.
  """

  @url "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd"

  @doc """
  Public function — returns {:ok, price} or {:error, reason}
  """
  def get_usd do
    case HTTPoison.get(@url, [], timeout: 10_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode!(body) do
          %{"bitcoin" => %{"usd" => price}} when is_number(price) ->
            # Return success tuple
            {:ok, price}

          _ ->
            # Return error atom
            {:error, :bad_format}
        end

      # Handle non-200 HTTP status
      {:ok, %HTTPoison.Response{status_code: code}} ->
        {:error, {:http, code}}

      # Handle network errors (timeout, DNS, etc.)
      {:error, reason} ->
        {:error, reason}
    end
  end
end

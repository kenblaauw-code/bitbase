defmodule BitbaseWeb.PriceLive do
  use BitbaseWeb, :live_view
  alias Bitbase.BitcoinPrice

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Process.send_after(self(), :update_price, 100)
    end

    {:ok,
     socket
     |> assign(:price, "—")
     |> assign(:change, "+0%")}
  end

  @impl true
  def handle_info(:update_price, socket) do
    socket =
      case BitcoinPrice.get_usd() do
        # {:ok, price} — Successful API response
        {:ok, price} ->
          # Enum.random(-5..15) — Random int in range (demo change)
          change = Enum.random(-5..15)

          socket
          |> assign(:price, format_price(price))
          |> assign(:change, format_change(change))

        # {:error, _} — Any error (network, parsing, etc.)
        {:error, _} ->
          assign(socket, :price, "Error - Come back later")
      end

    # Reschedule next update — 30,000 ms = 30 seconds
    Process.send_after(self(), :update_price, 30_000)

    # {:noreply, socket} — Tells LiveView to push changes to browser
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-main min-h-screen flex items-center justify-center p-4">
      <div class="price-card p-8 rounded-2xl shadow-2xl text-center max-w-md w-full">
        <p class="text-lg text-gray-300 mb-2">Current BTC Price</p>
        <p class="text-6xl font-mono text-white"><%= @price %></p>
        <p class={"text-2xl mt-2 #{if String.starts_with?(@change, "+"), do: "text-green-400", else: "text-red-400"}"}>
          <%= @change %>
        </p>
      </div>
    </div>
    <footer class="text-center text-sm text-gray-500 mt-12 fixed bottom-4 left-0 right-0">
      Updates every 30 seconds • Powered by CoinGecko
    </footer>
    """
  end

  defp format_price(price) when is_integer(price) do
    "$#{Number.Delimit.number_to_delimited(price)}"
  end

  defp format_price(price) when is_float(price) do
    "$#{Number.Delimit.number_to_delimited(trunc(Float.round(price, 0)))}"
  end

  # Function clauses with guard (when) — Like method overloading
  defp format_change(change) when change >= 0, do: "+#{change}%"
  defp format_change(change), do: "#{change}%"
end

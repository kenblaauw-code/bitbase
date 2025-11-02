defmodule BitbaseWeb.PriceLive do
  use BitbaseWeb, :live_view
  alias Bitbase.BitcoinPrice

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :update_price, 100)
    {:ok, assign(socket, price: "—", change: "+0%", prev_price: nil)}
  end

  @impl true
  def handle_info(:update_price, socket) do
    case BitcoinPrice.get_usd() do
      {:ok, current_price} ->
        {new_price_str, change} =
          case socket.assigns.prev_price do
            nil ->
              {format_price(current_price), "+0%"}

            prev_price when is_number(prev_price) ->
              change_percent = (current_price - prev_price) / prev_price * 100

              change_str =
                if change_percent >= 0,
                  do: "+#{:erlang.float_to_binary(change_percent, decimals: 2)}%",
                  else: "#{:erlang.float_to_binary(change_percent, decimals: 2)}%"

              {format_price(current_price), change_str}
          end

        socket =
          socket
          |> assign(:price, new_price_str)
          |> assign(:change, change)
          # Store for next tick
          |> assign(:prev_price, current_price)

        Process.send_after(self(), :update_price, 30_000)
        {:noreply, socket}

      {:error, _} ->
        assign(socket, :price, "offline")
    end
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

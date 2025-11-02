defmodule BitbaseWeb.PriceLive do
  use BitbaseWeb, :live_view
  alias Bitbase.{BitcoinPrice, PriceHistory}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:price, "—")
      |> assign(:change, "+0%")
      |> assign(:prev_price, nil)
      |> assign(:selected_range, "1D")
      |> assign(:ranges, ["1D", "1W", "1M", "YTD", "1Y"])
      |> assign(:chart_points, [])

    if connected?(socket) do
      socket = update_price(socket)
      socket = update_chart(socket, "1D")
      Process.send_after(self(), :update, 30_000)
      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_info(:update, socket) do
    socket = update_price(socket)
    socket = update_chart(socket, socket.assigns.selected_range)
    Process.send_after(self(), :update, 30_000)
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_range", %{"range" => range}, socket) do
    socket =
      socket
      |> assign(:selected_range, range)
      |> update_chart(range)

    {:noreply, socket}
  end

  defp update_price(socket) do
    case BitcoinPrice.get_usd() do
      {:ok, price} ->
        {price_str, change_str} =
          case socket.assigns.prev_price do
            nil ->
              {format_price(price), "+0%"}

            prev ->
              pct = (price - prev) / prev * 100

              change_str =
                if pct >= 0, do: "+#{Float.round(pct, 2)}%", else: "#{Float.round(pct, 2)}%"

              {format_price(price), change_str}
          end

        socket
        |> assign(:price, price_str)
        |> assign(:change, change_str)
        |> assign(:prev_price, price)

      {:error, _} ->
        assign(socket, :price, "offline")
    end
  end

  defp update_chart(socket, range) do
    case PriceHistory.fetch(range) do
      {:ok, points} ->
        assign(socket, :chart_points, points)

      {:error, _} ->
        assign(socket, :chart_points, [])
    end
  end

  defp format_price(p) when is_integer(p), do: "$#{Number.Delimit.number_to_delimited(p)}"

  defp format_price(p) when is_float(p),
    do: "$#{Number.Delimit.number_to_delimited(trunc(Float.round(p, 0)))}"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-main min-h-screen p-4">
      <div class="price-card p-8 rounded-2xl shadow-2xl text-center max-w-md mx-auto mb-8">
        <p class="text-lg text-gray-300 mb-2">Current BTC Price</p>
        <p class="text-6xl font-mono text-white"><%= @price %></p>
        <p class={"text-2xl mt-2 #{if String.starts_with?(@change, "+"), do: "text-green-400", else: "text-red-400"}"}>
          <%= @change %>
        </p>
      </div>

      <div class="flex justify-center space-x-2 mb-6">
        <%= for r <- @ranges do %>
          <button
            phx-click="select_range"
            phx-value-range={r}
            class={"px-4 py-1 rounded text-sm font-medium #{if @selected_range == r, do: "bg-orange-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600"}"}>
            <%= r %>
          </button>
        <% end %>
      </div>

      <div class="bg-table-body rounded-lg p-4 max-w-2xl mx-auto">
        <%= if length(@chart_points) > 1 do %>
          <.sparkline points={@chart_points} />
        <% else %>
          <p class="text-center text-gray-400">Loading chart…</p>
        <% end %>
      </div>

      <footer class="text-center text-sm text-gray-500 mt-12">
        Updates every 30 seconds • Powered by CoinGecko
      </footer>
    </div>
    """
  end

  defp sparkline(assigns) do
    points = assigns.points
    points = Enum.map(points, &List.to_tuple/1)
    prices = Enum.map(points, fn {_ts, p} -> p end)
    {min, max} = Enum.min_max(prices)

    chart_width = 600
    chart_height = 120
    padding = 20

    path =
      points
      |> Enum.with_index()
      |> Enum.map(fn {{_ts, p}, i} ->
        x = padding + i / (length(points) - 1) * (chart_width - 2 * padding)
        y = chart_height - padding - (p - min) / (max - min) * (chart_height - 2 * padding)
        "#{if i == 0, do: "M", else: "L"} #{Float.round(x, 1)},#{Float.round(y, 1)}"
      end)
      |> Enum.join(" ")

    assigns = assign(assigns, :sparkline_path, path)

    ~H"""
    <svg width="600" height="120" class="w-full">
      <path d={@sparkline_path} fill="none" stroke="#f97316" stroke-width="2" />
    </svg>
    """
  end
end

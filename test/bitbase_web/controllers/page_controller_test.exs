defmodule BitbaseWeb.PageControllerTest do
  use BitbaseWeb.ConnCase

  test "GET / renders PriceLive", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Current BTC Price"
  end
end

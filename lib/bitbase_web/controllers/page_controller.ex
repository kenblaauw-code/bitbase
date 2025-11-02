defmodule BitbaseWeb.PageController do
  use BitbaseWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

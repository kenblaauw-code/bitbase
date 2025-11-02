defmodule Bitbase.Repo do
  use Ecto.Repo,
    otp_app: :bitbase,
    adapter: Ecto.Adapters.Postgres
end

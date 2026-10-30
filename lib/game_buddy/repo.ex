defmodule GameBuddy.Repo do
  use Ecto.Repo,
    otp_app: :game_buddy,
    adapter: Ecto.Adapters.Postgres
end

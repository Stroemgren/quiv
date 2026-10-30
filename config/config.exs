# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :game_buddy, GameBuddy.Repo, types: GameBuddy.PostgrexTypes

# Game Buddy: which game slug tools default to when the caller does not say.
config :game_buddy, :default_game, "eu5"

# Record full tool-call payloads in telemetry (used by the /dashboard inspector).
config :anubis_mcp, telemetry_capture_tool_payload: true

# Local embeddings (Bumblebee). Enabled per environment. The Nx backend and defn
# compiler follow the platform: EMLX (Apple MLX on the Metal GPU) on macOS, EXLA
# (CPU, or CUDA when XLA_TARGET says so) elsewhere. Measured on an M3 Pro with
# bge-small at 256 tokens, batch 64: EMLX ~135-150 chunks/s vs EXLA CPU ~40 chunks/s.
{nx_backend, nx_compiler} =
  case :os.type() do
    {:unix, :darwin} -> {{EMLX.Backend, device: :gpu}, EMLX}
    _ -> {EXLA.Backend, EXLA}
  end

config :game_buddy, :embeddings, enabled: false
config :nx, default_backend: nx_backend, default_defn_options: [compiler: nx_compiler]

config :game_buddy,
  ecto_repos: [GameBuddy.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :game_buddy, GameBuddyWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: GameBuddyWeb.ErrorHTML, json: GameBuddyWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: GameBuddy.PubSub,
  live_view: [signing_salt: "+xZAoa7A"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  game_buddy: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  game_buddy: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

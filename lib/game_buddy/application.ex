defmodule GameBuddy.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    GameBuddy.ToolCalls.Telemetry.attach()

    children =
      [
        GameBuddyWeb.Telemetry,
        GameBuddy.Repo,
        # every adapter's game exists in the catalog, with or without data
        # (off in tests, where the sandbox owns the connections)
        if(Application.get_env(:game_buddy, :ensure_games, true),
          do:
            Supervisor.child_spec({Task, &GameBuddy.Catalog.ensure_games/0},
              id: :ensure_games,
              restart: :temporary
            )
        ),
        if(GameBuddy.Embeddings.enabled?(), do: GameBuddy.Embeddings),
        {DNSCluster, query: Application.get_env(:game_buddy, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: GameBuddy.PubSub},
        {Task.Supervisor, name: GameBuddy.TaskSupervisor},
        # Start a worker by calling: GameBuddy.Worker.start_link(arg)
        # {GameBuddy.Worker, arg},
        {GameBuddy.MCP.Server, transport: :streamable_http},
        # Start to serve requests, typically the last entry
        GameBuddyWeb.Endpoint
      ]
      |> Enum.reject(&is_nil/1)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GameBuddy.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GameBuddyWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

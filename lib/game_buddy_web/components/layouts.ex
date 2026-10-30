defmodule GameBuddyWeb.Layouts do
  @moduledoc """
  Layouts: `site/1` wraps the public pages (header, footer), `app/1` the internal
  tools such as the dashboard. Both are composed from `GameBuddyWeb.SiteComponents`.
  """
  use GameBuddyWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @nav_links [
    {"Features", "/#features"},
    {"Games", "/#games"},
    {"How it works", "/#how-it-works"},
    {"Platform", "/#platform"},
    {"Design", "/design"}
  ]

  @doc """
  The public site's layout: sticky header with the primary navigation, the page,
  and the footer.

  The header is a frosted light bar. Over a dark band at the top of the page
  (`header_theme="dark"`, with `data-header-dark` on the band) it starts out
  transparent with white text and turns into a frosted night bar once the page
  scrolls; `assets/js/site.js` keeps `data-theme` and `data-scrolled` current.

  ## Examples

      <Layouts.site flash={@flash} header_theme="dark">
        <.night_panel bleed data-header-dark class="-mt-16 pt-28">…</.night_panel>
      </Layouts.site>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :header_theme, :string,
    default: "light",
    values: ~w(light dark),
    doc: "the header's look before any scrolling: dark when the page opens on a dark band"

  slot :inner_block, required: true

  def site(assigns) do
    assigns = assign(assigns, :nav_links, @nav_links)

    ~H"""
    <div class="flex min-h-screen flex-col">
      <header
        data-site-header
        data-theme={@header_theme}
        class={[
          "group/header sticky top-0 z-40 border-b transition-colors duration-200",
          "border-line/70 bg-canvas/85 backdrop-blur",
          "data-[theme=dark]:border-transparent data-[theme=dark]:bg-transparent data-[theme=dark]:backdrop-blur-none",
          "data-[theme=dark]:data-scrolled:border-white/10 data-[theme=dark]:data-scrolled:bg-night/75 data-[theme=dark]:data-scrolled:backdrop-blur"
        ]}
      >
        <.container class="flex h-16 items-center gap-6">
          <.logo adaptive />
          <nav class="hidden items-center gap-1 md:flex" aria-label="Primary">
            <a
              :for={{label, href} <- @nav_links}
              href={href}
              class="rounded-full px-3 py-1.5 text-sm font-semibold text-ink-soft transition-colors hover:bg-muted hover:text-ink group-data-[theme=dark]/header:text-white/80 group-data-[theme=dark]/header:hover:bg-white/10 group-data-[theme=dark]/header:hover:text-white"
            >
              {label}
            </a>
          </nav>
          <div class="ml-auto hidden items-center gap-2 md:flex">
            <.button
              variant="ghost"
              size="sm"
              href="/dashboard"
              icon="hero-signal"
              class="group-data-[theme=dark]/header:text-white/80 group-data-[theme=dark]/header:hover:bg-white/10 group-data-[theme=dark]/header:hover:text-white"
            >
              Dashboard
            </.button>
            <.button size="sm" href="/#how-it-works" trailing_icon="hero-arrow-right">
              Connect your assistant
            </.button>
          </div>
          <button
            type="button"
            class="ml-auto grid size-10 place-items-center rounded-full text-ink-soft hover:bg-muted hover:text-ink group-data-[theme=dark]/header:text-white/80 group-data-[theme=dark]/header:hover:bg-white/10 group-data-[theme=dark]/header:hover:text-white md:hidden"
            data-toggle="site-menu"
            aria-controls="site-menu"
            aria-expanded="false"
            aria-label="Menu"
          >
            <.icon name="hero-bars-3" class="size-6" />
          </button>
        </.container>
        <div
          id="site-menu"
          class="hidden border-t border-line bg-canvas group-data-[theme=dark]/header:border-white/10 group-data-[theme=dark]/header:bg-night md:hidden"
        >
          <.container class="flex flex-col gap-1 py-3">
            <a
              :for={{label, href} <- @nav_links ++ [{"Dashboard", "/dashboard"}]}
              href={href}
              class="rounded-xl px-3 py-2 text-sm font-semibold text-ink-soft hover:bg-muted hover:text-ink group-data-[theme=dark]/header:text-white/80 group-data-[theme=dark]/header:hover:bg-white/10 group-data-[theme=dark]/header:hover:text-white"
            >
              {label}
            </a>
            <.button href="/#how-it-works" class="mt-2" trailing_icon="hero-arrow-right">
              Connect your assistant
            </.button>
          </.container>
        </div>
      </header>

      <main class="grow">
        {render_slot(@inner_block)}
      </main>

      <footer class="border-t border-line bg-surface">
        <.container class="grid gap-10 py-14 md:grid-cols-[1.5fr_1fr_1fr]">
          <div>
            <.logo />
            <p class="mt-4 max-w-xs text-sm text-ink-soft">
              Game knowledge from the game's own files. No wikis, no guesses, every fact with its source.
            </p>
          </div>
          <div>
            <h2 class="text-xs font-bold uppercase tracking-[0.14em] text-ink-soft">Product</h2>
            <ul class="mt-4 space-y-2 text-sm">
              <li :for={{label, href} <- Enum.take(@nav_links, 4)}>
                <a href={href} class="font-semibold text-ink hover:text-brand">{label}</a>
              </li>
            </ul>
          </div>
          <div>
            <h2 class="text-xs font-bold uppercase tracking-[0.14em] text-ink-soft">Developers</h2>
            <ul class="mt-4 space-y-2 text-sm">
              <li>
                <a href="/#how-it-works" class="font-semibold text-ink hover:text-brand">
                  MCP endpoint
                </a>
              </li>
              <li>
                <a href="/dashboard" class="font-semibold text-ink hover:text-brand">Dashboard</a>
              </li>
              <li>
                <a href="/design" class="font-semibold text-ink hover:text-brand">Design system</a>
              </li>
            </ul>
          </div>
        </.container>
        <div class="border-t border-line">
          <.container class="flex flex-wrap items-center justify-between gap-3 py-5 text-xs text-ink-soft">
            <p>© 2026 Quiv</p>
            <p>Built on Phoenix. Served over the Model Context Protocol.</p>
          </.container>
        </div>
      </footer>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  @doc """
  The layout for internal tools: a slim header and the page.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :title, :string, default: nil, doc: "the tool's name, shown next to the logo"
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="border-b border-line bg-surface">
      <.container class="flex h-14 items-center gap-4">
        <.logo size="sm" />
        <.pill :if={@title} tone="neutral" size="sm">{@title}</.pill>
        <nav class="ml-auto flex items-center gap-1" aria-label="Tools">
          <.button variant="ghost" size="sm" href="/">Site</.button>
          <.button variant="ghost" size="sm" href="/design">Design</.button>
        </nav>
      </.container>
    </header>

    <main class="py-8">
      <.container>
        {render_slot(@inner_block)}
      </.container>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="We can't find the internet"
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong!"
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end

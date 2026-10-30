defmodule GameBuddyWeb.SiteComponents do
  @moduledoc """
  The design system as function components: brand marks and the mascot, buttons,
  pills, form fields, navigation, feedback and content cards. `/design` shows every
  one of them with its usage; the landing page and the dashboard are composed from
  them. Styling is plain Tailwind on the tokens declared in `assets/css/app.css`.
  """
  use Phoenix.Component
  import GameBuddyWeb.CoreComponents, only: [icon: 1]

  # ---------------------------------------------------------------------------
  # Layout helpers
  # ---------------------------------------------------------------------------

  @doc "Centers content at the site's measure with the page gutter."
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def container(assigns) do
    ~H"""
    <div class={["mx-auto w-full max-w-6xl px-4 sm:px-6", @class]} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  A dark panel. Rounded as a card by default; `bleed` makes it a full-width band
  (the hero, the demo and the closing call to action), in which case the content
  goes in a `.container`. Add `data-header-dark` to a band at the top of the page
  so the site header turns transparent over it.
  """
  attr :class, :any, default: nil
  attr :glow, :boolean, default: true
  attr :bleed, :boolean, default: false, doc: "full width, no rounded corners"
  attr :rest, :global
  slot :inner_block, required: true

  def night_panel(assigns) do
    ~H"""
    <div
      class={[
        "relative overflow-hidden bg-night text-white",
        "bg-gradient-to-br from-night via-night-2 to-night",
        !@bleed && "rounded-[2rem]",
        @class
      ]}
      {@rest}
    >
      <div class="pointer-events-none absolute inset-0 dot-grid" aria-hidden="true"></div>
      <div :if={@glow} class="pointer-events-none absolute inset-0 night-glow" aria-hidden="true">
      </div>
      <div class="relative">{render_slot(@inner_block)}</div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Brand
  # ---------------------------------------------------------------------------

  @doc "The app icon: a violet rounded square with the buddy's face."
  attr :size, :integer, default: 40
  attr :class, :any, default: nil
  attr :rest, :global

  def mark(assigns) do
    ~H"""
    <svg
      width={@size}
      height={@size}
      viewBox="0 0 128 128"
      class={["shrink-0", @class]}
      aria-hidden="true"
      {@rest}
    >
      <defs>
        <clipPath id="gb-mark-clip"><rect width="128" height="128" rx="30" /></clipPath>
      </defs>
      <rect width="128" height="128" rx="30" fill="#6c4dff" />
      <circle cx="22" cy="14" r="60" fill="#8b9cff" opacity=".9" clip-path="url(#gb-mark-clip)" />
      <ellipse cx="66" cy="74" rx="40" ry="35" fill="#fff" />
      <ellipse cx="52" cy="73" rx="5.5" ry="8" fill="#1b1a3d" />
      <ellipse cx="80" cy="73" rx="5.5" ry="8" fill="#1b1a3d" />
      <circle cx="53.5" cy="69.5" r="1.8" fill="#fff" />
      <circle cx="81.5" cy="69.5" r="1.8" fill="#fff" />
      <path
        d="M61 87q5 4.5 10 0"
        stroke="#1b1a3d"
        stroke-width="2.2"
        stroke-linecap="round"
        fill="none"
      />
    </svg>
    """
  end

  @doc """
  Wordmark with the app icon. `on_dark` sets the name in white; `adaptive` follows
  the site header's `data-theme` instead (used in the header only).
  """
  attr :size, :string, default: "md", values: ~w(sm md lg)
  attr :on_dark, :boolean, default: false
  attr :adaptive, :boolean, default: false
  attr :href, :string, default: "/"
  attr :class, :any, default: nil

  def logo(assigns) do
    text =
      cond do
        assigns.adaptive -> "text-ink group-data-[theme=dark]/header:text-white"
        assigns.on_dark -> "text-white"
        true -> "text-ink"
      end

    assigns =
      assign(assigns,
        text: text,
        spec: %{"sm" => {28, "text-lg"}, "md" => {36, "text-xl"}, "lg" => {56, "text-4xl"}}
      )

    ~H"""
    <a
      href={@href}
      class={["inline-flex items-center gap-2.5 font-extrabold tracking-tight", @text, @class]}
    >
      <.mark size={elem(@spec[@size], 0)} />
      <span class={["leading-none", elem(@spec[@size], 1)]}>Quiv</span>
    </a>
    """
  end

  @doc """
  The mascot, Quiv: an SVG character. Expressions: happy, wink, excited, curious.
  Size it with a class (`class="size-40"`).
  """
  attr :expression, :string, default: "happy", values: ~w(happy wink excited curious)
  attr :class, :any, default: "size-40"
  attr :rest, :global

  def mascot(assigns) do
    ~H"""
    <svg viewBox="0 0 240 240" class={["shrink-0", @class]} aria-hidden="true" {@rest}>
      <defs>
        <linearGradient id={"gb-mascot-#{@expression}"} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stop-color="#8b9cff" />
          <stop offset="1" stop-color="#6c4dff" />
        </linearGradient>
      </defs>
      <ellipse cx="46" cy="178" rx="26" ry="13" transform="rotate(-35 46 178)" fill="#8b9cff" />
      <ellipse cx="200" cy="172" rx="26" ry="13" transform="rotate(30 200 172)" fill="#8b9cff" />
      <ellipse cx="88" cy="46" rx="13" ry="34" transform="rotate(-18 88 46)" fill="#6c4dff" />
      <ellipse cx="158" cy="56" rx="10" ry="24" transform="rotate(22 158 56)" fill="#6c4dff" />
      <path
        d="M118 36c58-4 100 30 100 86 0 50-44 86-98 86-34 0-66-12-86-36C14 150 20 92 48 64c18-18 44-26 70-28z"
        fill={"url(#gb-mascot-#{@expression})"}
      />
      <ellipse cx="112" cy="128" rx="72" ry="64" fill="#fff" />
      <ellipse cx="70" cy="146" rx="8" ry="5" fill="#ff6b8b" opacity=".35" />
      <ellipse cx="156" cy="146" rx="8" ry="5" fill="#ff6b8b" opacity=".35" />
      <%= case @expression do %>
        <% "wink" -> %>
          <ellipse cx="88" cy="126" rx="10" ry="14" fill="#1b1a3d" />
          <circle cx="91" cy="120" r="3.2" fill="#fff" />
          <path
            d="M128 126q10-10 20 0"
            stroke="#1b1a3d"
            stroke-width="4"
            stroke-linecap="round"
            fill="none"
          />
          <path
            d="M100 150q13 12 26 0"
            stroke="#1b1a3d"
            stroke-width="3.5"
            stroke-linecap="round"
            fill="none"
          />
        <% "excited" -> %>
          <ellipse cx="88" cy="124" rx="12" ry="16" fill="#1b1a3d" />
          <ellipse cx="138" cy="124" rx="12" ry="16" fill="#1b1a3d" />
          <circle cx="92" cy="117" r="4" fill="#fff" />
          <circle cx="142" cy="117" r="4" fill="#fff" />
          <path d="M100 148q13 20 26 0z" fill="#1b1a3d" />
          <path d="M106 156q7 6 14 0z" fill="#ff6b8b" />
          <path d="M22 60l3 8 8 3-8 3-3 8-3-8-8-3 8-3z" fill="#ffc857" />
          <path d="M212 40l2.5 6.5 6.5 2.5-6.5 2.5-2.5 6.5-2.5-6.5-6.5-2.5 6.5-2.5z" fill="#a6f45b" />
        <% "curious" -> %>
          <ellipse cx="92" cy="122" rx="10" ry="14" fill="#1b1a3d" />
          <ellipse cx="142" cy="122" rx="10" ry="14" fill="#1b1a3d" />
          <circle cx="97" cy="116" r="3.2" fill="#fff" />
          <circle cx="147" cy="116" r="3.2" fill="#fff" />
          <path
            d="M128 100q10-6 18 2"
            stroke="#1b1a3d"
            stroke-width="3"
            stroke-linecap="round"
            fill="none"
          />
          <ellipse cx="116" cy="152" rx="6" ry="7" fill="#1b1a3d" />
        <% _ -> %>
          <ellipse cx="88" cy="126" rx="10" ry="14" fill="#1b1a3d" />
          <ellipse cx="138" cy="126" rx="10" ry="14" fill="#1b1a3d" />
          <circle cx="91" cy="120" r="3.2" fill="#fff" />
          <circle cx="141" cy="120" r="3.2" fill="#fff" />
          <path
            d="M104 150q9 8 18 0"
            stroke="#1b1a3d"
            stroke-width="3.5"
            stroke-linecap="round"
            fill="none"
          />
      <% end %>
    </svg>
    """
  end

  # ---------------------------------------------------------------------------
  # Buttons
  # ---------------------------------------------------------------------------

  @button_base "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-full font-semibold transition-[background-color,box-shadow,transform,color] duration-150 focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-brand/25 disabled:pointer-events-none disabled:opacity-40 active:translate-y-px"

  @button_sizes %{
    "sm" => "h-9 px-4 text-sm",
    "md" => "h-11 px-5 text-sm",
    "lg" => "h-13 px-7 text-base"
  }

  @button_variants %{
    "primary" => %{
      base:
        "bg-brand text-white shadow-sm hover:bg-brand-hover hover:shadow-md active:bg-brand-active active:shadow-xs",
      hover: "bg-brand-hover text-white shadow-md",
      active: "bg-brand-active text-white shadow-xs"
    },
    "secondary" => %{
      base: "bg-lavender text-brand-deep hover:bg-lavender-2 active:bg-brand-soft/60",
      hover: "bg-lavender-2 text-brand-deep",
      active: "bg-brand-soft/60 text-brand-deep"
    },
    "ghost" => %{
      base: "bg-transparent text-ink-soft hover:bg-muted hover:text-ink active:bg-line",
      hover: "bg-muted text-ink",
      active: "bg-line text-ink"
    },
    "destructive" => %{
      base:
        "bg-coral text-white shadow-sm hover:bg-coral-deep active:bg-coral-deep active:shadow-xs",
      hover: "bg-coral-deep text-white shadow-sm",
      active: "bg-coral-deep text-white shadow-xs"
    },
    "light" => %{
      base: "bg-white text-night shadow-sm hover:bg-lavender active:bg-lavender-2",
      hover: "bg-lavender text-night shadow-sm",
      active: "bg-lavender-2 text-night"
    },
    "outline" => %{
      base: "border border-white/25 bg-white/0 text-white hover:bg-white/10 active:bg-white/15",
      hover: "border border-white/25 bg-white/10 text-white",
      active: "border border-white/25 bg-white/15 text-white"
    }
  }

  @doc """
  A button, or a link that looks like one when `href`, `navigate` or `patch` is set.

  Variants: primary, secondary, ghost, destructive, and light / outline for dark panels.
  `state` forces the hover or active look (for the design system page only).
  """
  attr :variant, :string, default: "primary", values: Map.keys(@button_variants)
  attr :size, :string, default: "md", values: Map.keys(@button_sizes)
  attr :state, :string, default: nil, values: [nil, "hover", "active"]
  attr :type, :string, default: "button"
  attr :icon, :string, default: nil, doc: "a leading heroicon name"
  attr :trailing_icon, :string, default: nil, doc: "a trailing heroicon name"
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled form)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    assigns = assign(assigns, :classes, button_classes(assigns))

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@classes} {@rest}>
        <.icon :if={@icon} name={@icon} class={button_icon_size(@size)} />
        {render_slot(@inner_block)}
        <.icon :if={@trailing_icon} name={@trailing_icon} class={button_icon_size(@size)} />
      </.link>
      """
    else
      ~H"""
      <button type={@type} class={@classes} {@rest}>
        <.icon :if={@icon} name={@icon} class={button_icon_size(@size)} />
        {render_slot(@inner_block)}
        <.icon :if={@trailing_icon} name={@trailing_icon} class={button_icon_size(@size)} />
      </button>
      """
    end
  end

  defp button_classes(assigns) do
    variant = Map.fetch!(@button_variants, assigns.variant)

    look =
      case assigns.state do
        nil -> variant.base
        "hover" -> variant.hover
        "active" -> variant.active
      end

    [@button_base, Map.fetch!(@button_sizes, assigns.size), look, assigns.class]
  end

  defp button_icon_size("lg"), do: "size-5"
  defp button_icon_size(_), do: "size-4"

  @icon_button_variants %{
    "primary" => "bg-brand text-white shadow-sm hover:bg-brand-hover",
    "secondary" => "bg-lavender text-brand hover:bg-lavender-2",
    "ghost" => "bg-transparent text-ink-soft hover:bg-muted hover:text-ink",
    "outline" => "border border-white/25 text-white hover:bg-white/10"
  }

  @doc "A round button holding one icon. `label` is required for screen readers."
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :variant, :string, default: "secondary", values: Map.keys(@icon_button_variants)
  attr :size, :string, default: "md", values: ~w(sm md)
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(href navigate disabled type)

  def icon_button(assigns) do
    assigns = assign(assigns, :look, Map.fetch!(@icon_button_variants, assigns.variant))

    ~H"""
    <button
      type="button"
      aria-label={@label}
      title={@label}
      class={[
        "inline-grid shrink-0 place-items-center rounded-full transition-colors duration-150",
        "focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-brand/25 disabled:pointer-events-none disabled:opacity-40",
        if(@size == "sm", do: "size-9", else: "size-11"),
        @look,
        @class
      ]}
      {@rest}
    >
      <.icon name={@icon} class={if(@size == "sm", do: "size-4", else: "size-5")} />
    </button>
    """
  end

  # ---------------------------------------------------------------------------
  # Labels, pills, chips
  # ---------------------------------------------------------------------------

  @doc "The short label that opens a section, above its title."
  attr :on_dark, :boolean, default: false
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def eyebrow(assigns) do
    ~H"""
    <p class={[
      "text-xs font-bold uppercase tracking-[0.14em]",
      if(@on_dark, do: "text-brand-soft", else: "text-brand"),
      @class
    ]}>
      {render_slot(@inner_block)}
    </p>
    """
  end

  @pill_tones %{
    "violet" => "bg-lavender text-brand-deep",
    "coral" => "bg-blush text-coral-deep",
    "lime" => "bg-mint text-lime-deep",
    "sun" => "bg-sand text-sun-deep",
    "neutral" => "bg-muted text-ink-soft",
    "night" => "bg-night text-white",
    "outline" => "border border-line bg-surface text-ink-soft",
    "glass" => "border border-white/15 bg-white/10 text-white"
  }

  @doc """
  A pill: tag, badge or status. `dot` adds a status dot, `icon` a leading heroicon.
  Tones: violet, coral, lime, sun, neutral, night, outline, glass.
  """
  attr :tone, :string, default: "violet", values: Map.keys(@pill_tones)
  attr :size, :string, default: "md", values: ~w(sm md)
  attr :icon, :string, default: nil
  attr :dot, :boolean, default: false
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def pill(assigns) do
    assigns = assign(assigns, :look, Map.fetch!(@pill_tones, assigns.tone))

    ~H"""
    <span
      class={[
        "inline-flex items-center gap-1.5 whitespace-nowrap rounded-full font-semibold",
        if(@size == "sm", do: "h-6 px-2.5 text-xs", else: "h-8 px-3 text-sm"),
        @look,
        @class
      ]}
      {@rest}
    >
      <span :if={@dot} class="size-1.5 rounded-full bg-current" aria-hidden="true"></span>
      <.icon :if={@icon} name={@icon} class="size-3.5" />
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc "A key or tool name as the clients see it: a small monospace chip."
  attr :on_dark, :boolean, default: false
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def key_chip(assigns) do
    ~H"""
    <code class={[
      "inline-flex h-6 items-center whitespace-nowrap rounded-md px-1.5 font-mono text-[11px] font-medium",
      if(@on_dark, do: "bg-white/10 text-brand-soft", else: "bg-lavender text-brand-deep"),
      @class
    ]}>
      {render_slot(@inner_block)}
    </code>
    """
  end

  @doc "A line with a check mark: the small reassurances under a hero."
  attr :on_dark, :boolean, default: false
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def check_item(assigns) do
    ~H"""
    <span class={["inline-flex items-center gap-2 text-sm font-medium", @class]}>
      <span class={[
        "grid size-5 shrink-0 place-items-center rounded-full",
        if(@on_dark, do: "bg-brand text-white", else: "bg-lavender text-brand")
      ]}>
        <.icon name="hero-check-mini" class="size-3.5" />
      </span>
      {render_slot(@inner_block)}
    </span>
    """
  end

  # ---------------------------------------------------------------------------
  # Section heading
  # ---------------------------------------------------------------------------

  @doc "Eyebrow, title and lead that open a page section, with optional actions."
  attr :eyebrow, :string, default: nil
  attr :title, :string, required: true
  attr :lead, :string, default: nil
  attr :on_dark, :boolean, default: false
  attr :level, :string, default: "h2", values: ~w(h1 h2 h3)
  attr :class, :any, default: nil
  slot :actions

  def section_heading(assigns) do
    ~H"""
    <div class={["max-w-xl", @class]}>
      <.eyebrow :if={@eyebrow} on_dark={@on_dark} class="mb-3">{@eyebrow}</.eyebrow>
      <.dynamic_tag
        tag_name={@level}
        class={[
          "text-balance",
          @level == "h1" && "text-h1",
          @level == "h2" && "text-h2",
          @level == "h3" && "text-h3",
          if(@on_dark, do: "text-white", else: "text-ink")
        ]}
      >
        {@title}
      </.dynamic_tag>
      <p
        :if={@lead}
        class={[
          "mt-4 text-lead text-pretty",
          if(@on_dark, do: "text-white/70", else: "text-ink-soft")
        ]}
      >
        {@lead}
      </p>
      <div :if={@actions != []} class="mt-6 flex flex-wrap gap-3">{render_slot(@actions)}</div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Cards
  # ---------------------------------------------------------------------------

  @tile_tones %{
    "violet" => "bg-brand text-white",
    "coral" => "bg-coral text-white",
    "lime" => "bg-lime text-ink",
    "sun" => "bg-sun text-ink",
    "night" => "bg-night text-white",
    "soft" => "bg-lavender text-brand"
  }

  @doc "A rounded square holding an icon, in one of the accent tones."
  attr :icon, :string, required: true
  attr :tone, :string, default: "violet", values: Map.keys(@tile_tones)
  attr :size, :string, default: "md", values: ~w(sm md lg)
  attr :class, :any, default: nil

  def icon_tile(assigns) do
    assigns = assign(assigns, :look, Map.fetch!(@tile_tones, assigns.tone))

    ~H"""
    <span class={[
      "grid shrink-0 place-items-center",
      @size == "sm" && "size-9 rounded-lg",
      @size == "md" && "size-12 rounded-xl",
      @size == "lg" && "size-16 rounded-2xl",
      @look,
      @class
    ]}>
      <.icon
        name={@icon}
        class={[
          @size == "sm" && "size-4",
          @size == "md" && "size-6",
          @size == "lg" && "size-8"
        ]}
      />
    </span>
    """
  end

  @doc "The base card surface. Everything else that is a card builds on it."
  attr :class, :any, default: nil
  attr :padded, :boolean, default: true
  attr :rest, :global
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div
      class={[
        "rounded-3xl bg-surface shadow-xs ring-1 ring-line/80",
        @padded && "p-6",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "A feature: icon tile, title and a short text. `layout` row puts the tile beside the text."
  attr :icon, :string, required: true
  attr :tone, :string, default: "violet"
  attr :title, :string, required: true
  attr :text, :string, required: true
  attr :layout, :string, default: "stack", values: ~w(stack row)
  attr :class, :any, default: nil
  slot :inner_block

  def feature_card(assigns) do
    ~H"""
    <.card class={[@layout == "row" && "flex gap-4", @class]}>
      <.icon_tile icon={@icon} tone={@tone} size={if(@layout == "row", do: "sm", else: "md")} />
      <div class={@layout == "stack" && "mt-5"}>
        <h3 class="text-base font-bold text-ink">{@title}</h3>
        <p class="mt-1.5 text-sm leading-relaxed text-ink-soft">{@text}</p>
        {render_slot(@inner_block)}
      </div>
    </.card>
    """
  end

  @doc "A number with its label."
  attr :icon, :string, default: nil
  attr :tone, :string, default: "violet"
  attr :value, :string, required: true
  attr :label, :string, required: true
  attr :text, :string, default: nil
  attr :class, :any, default: nil

  def stat_card(assigns) do
    ~H"""
    <.card class={@class}>
      <.icon_tile :if={@icon} icon={@icon} tone={@tone} size="sm" class="mb-4" />
      <p class="text-h3 text-ink">{@value}</p>
      <p class="mt-1 text-sm font-semibold text-ink">{@label}</p>
      <p :if={@text} class="mt-1 text-sm text-ink-soft">{@text}</p>
    </.card>
    """
  end

  @doc "A quote with who said it."
  attr :quote, :string, required: true
  attr :name, :string, required: true
  attr :role, :string, default: nil
  attr :class, :any, default: nil

  def quote_card(assigns) do
    ~H"""
    <.card class={["flex flex-col", @class]}>
      <p class="grow text-pretty text-base leading-relaxed text-ink">“{@quote}”</p>
      <div class="mt-6 flex items-center gap-3">
        <span class="grid size-10 place-items-center rounded-full bg-lavender text-sm font-bold text-brand-deep">
          {String.first(@name)}
        </span>
        <div class="text-sm">
          <p class="font-semibold text-ink">{@name}</p>
          <p :if={@role} class="text-ink-soft">{@role}</p>
        </div>
      </div>
    </.card>
    """
  end

  @doc "A numbered step with room for an illustration."
  attr :number, :integer, required: true
  attr :title, :string, required: true
  attr :text, :string, required: true
  attr :class, :any, default: nil
  slot :inner_block

  def step_card(assigns) do
    ~H"""
    <.card class={["flex flex-col", @class]}>
      <div class="flex items-start gap-4">
        <span class="grid size-9 shrink-0 place-items-center rounded-xl bg-brand text-sm font-bold text-white">
          {@number}
        </span>
        <div>
          <h3 class="text-base font-bold text-ink">{@title}</h3>
          <p class="mt-1 text-sm leading-relaxed text-ink-soft">{@text}</p>
        </div>
      </div>
      <div :if={@inner_block != []} class="mt-6 grow">{render_slot(@inner_block)}</div>
    </.card>
    """
  end

  @doc """
  A game in the catalog: its icon, status, name and a line of meta. `image` is the
  game's own small icon (`/images/games/<slug>/icon.png`, fetched by
  `scripts/steam_art.py`); without one the card draws a tile in the slug's colours.
  """
  attr :name, :string, required: true
  attr :slug, :string, required: true
  attr :status, :string, default: "soon", values: ~w(live soon)
  attr :meta, :string, default: nil
  attr :image, :string, default: nil
  attr :class, :any, default: nil

  def game_card(assigns) do
    ~H"""
    <.card class={["flex flex-col", @class]}>
      <div class="flex items-start justify-between gap-3">
        <.game_icon slug={@slug} image={@image} size="lg" />
        <.pill tone={if(@status == "live", do: "lime", else: "neutral")} size="sm" dot>
          {if @status == "live", do: "Live", else: "Coming soon"}
        </.pill>
      </div>
      <h3 class="mt-4 text-base font-bold text-ink">{@name}</h3>
      <p :if={@meta} class="mt-0.5 text-xs text-ink-soft">{@meta}</p>
    </.card>
    """
  end

  @doc """
  A game's small icon, for next to its name: the game's own icon when there is one,
  else a tile in the slug's colours with a glyph. Sizes: xs (16 px, inline in a
  sentence), sm (24 px, in a list row), md (32 px), lg (48 px, on a card).
  """
  attr :slug, :string, required: true
  attr :image, :string, default: nil
  attr :size, :string, default: "md", values: ~w(xs sm md lg)
  attr :class, :any, default: nil

  def game_icon(assigns) do
    assigns =
      assign(assigns,
        art: game_art(assigns.slug),
        spec: %{
          "xs" => {"size-4 rounded", "size-2.5"},
          "sm" => {"size-6 rounded-md", "size-3.5"},
          "md" => {"size-8 rounded-lg", "size-4"},
          "lg" => {"size-12 rounded-xl", "size-6"}
        }
      )

    ~H"""
    <img
      :if={@image}
      src={@image}
      alt=""
      class={["shrink-0 bg-muted object-cover ring-1 ring-line/80", elem(@spec[@size], 0), @class]}
    />
    <span
      :if={!@image}
      class={[
        "grid shrink-0 place-items-center bg-gradient-to-br text-white",
        elem(@art, 0),
        elem(@spec[@size], 0),
        @class
      ]}
      aria-hidden="true"
    >
      <.icon name={elem(@art, 1)} class={elem(@spec[@size], 1)} />
    </span>
    """
  end

  defp game_art("eu5"),
    do: {"from-brand-deep via-brand to-brand-soft", "hero-globe-europe-africa"}

  defp game_art("civ7"), do: {"from-sun-deep via-sun to-sand", "hero-building-library"}
  defp game_art("hoi4"), do: {"from-night via-night-3 to-coral", "hero-shield-check"}
  defp game_art(_), do: {"from-ink-soft via-ink-faint to-line", "hero-puzzle-piece"}

  # ---------------------------------------------------------------------------
  # Conversation
  # ---------------------------------------------------------------------------

  @doc "One turn of a conversation. `from` is user or buddy."
  attr :from, :string, default: "buddy", values: ~w(user buddy)
  attr :on_dark, :boolean, default: false
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def chat_bubble(assigns) do
    ~H"""
    <div class={["flex items-start gap-3", @from == "user" && "flex-row-reverse", @class]}>
      <%= if @from == "buddy" do %>
        <.mark size={32} />
      <% else %>
        <span class={[
          "grid size-8 shrink-0 place-items-center rounded-full",
          if(@on_dark, do: "bg-white/15 text-white", else: "bg-muted text-ink-soft")
        ]}>
          <.icon name="hero-user-solid" class="size-4" />
        </span>
      <% end %>
      <div class={[
        "max-w-[85%] rounded-2xl px-4 py-3 text-sm leading-relaxed",
        @from == "buddy" && "rounded-tl-md",
        @from == "user" && "rounded-tr-md",
        @from == "buddy" && if(@on_dark, do: "bg-white/10 text-white", else: "bg-lavender text-ink"),
        @from == "user" &&
          if(@on_dark,
            do: "bg-white text-ink",
            else: "bg-surface text-ink ring-1 ring-line"
          )
      ]}>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Form fields
  # ---------------------------------------------------------------------------

  @field_base "block w-full rounded-xl border border-line bg-surface text-sm text-ink shadow-xs transition placeholder:text-ink-faint hover:border-ink-faint focus:border-brand focus:outline-none focus:ring-4 focus:ring-brand/15 disabled:bg-muted disabled:text-ink-faint"

  @doc "A text-like input with an optional label, leading icon, hint and error."
  attr :id, :string, required: true
  attr :name, :string, default: nil
  attr :label, :string, default: nil
  attr :type, :string, default: "text"
  attr :icon, :string, default: nil
  attr :hint, :string, default: nil
  attr :error, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(placeholder value disabled required autocomplete)

  def text_field(assigns) do
    assigns = assign(assigns, :base, @field_base)

    ~H"""
    <div class={@class}>
      <label :if={@label} for={@id} class="mb-1.5 block text-sm font-semibold text-ink">
        {@label}
      </label>
      <div class="relative">
        <.icon
          :if={@icon}
          name={@icon}
          class="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-ink-faint"
        />
        <input
          id={@id}
          name={@name || @id}
          type={@type}
          class={[
            @base,
            "h-11",
            if(@icon, do: "pl-10 pr-3.5", else: "px-3.5"),
            @error && "border-coral focus:border-coral focus:ring-coral/15"
          ]}
          aria-invalid={@error && "true"}
          {@rest}
        />
      </div>
      <p :if={@hint && !@error} class="mt-1.5 text-xs text-ink-soft">{@hint}</p>
      <p :if={@error} class="mt-1.5 flex items-center gap-1 text-xs font-medium text-coral-deep">
        <.icon name="hero-exclamation-circle-mini" class="size-4" /> {@error}
      </p>
    </div>
    """
  end

  @doc "A search input: magnifier, pill shape, optional keyboard hint."
  attr :id, :string, required: true
  attr :name, :string, default: "q"
  attr :placeholder, :string, default: "Search"
  attr :kbd, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(value disabled)

  def search_field(assigns) do
    assigns = assign(assigns, :base, @field_base)

    ~H"""
    <div class={["relative", @class]}>
      <.icon
        name="hero-magnifying-glass"
        class="pointer-events-none absolute left-4 top-1/2 size-4 -translate-y-1/2 text-ink-faint"
      />
      <input
        id={@id}
        name={@name}
        type="search"
        placeholder={@placeholder}
        class={[@base, "h-11 rounded-full pl-11", if(@kbd, do: "pr-14", else: "pr-4")]}
        {@rest}
      />
      <kbd
        :if={@kbd}
        class="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 rounded-md border border-line bg-muted px-1.5 py-0.5 font-sans text-[11px] font-semibold text-ink-soft"
      >
        {@kbd}
      </kbd>
    </div>
    """
  end

  @doc "A multi-line text input."
  attr :id, :string, required: true
  attr :name, :string, default: nil
  attr :label, :string, default: nil
  attr :rows, :integer, default: 4
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(placeholder disabled required)
  slot :inner_block

  def textarea_field(assigns) do
    assigns = assign(assigns, :base, @field_base)

    ~H"""
    <div class={@class}>
      <label :if={@label} for={@id} class="mb-1.5 block text-sm font-semibold text-ink">
        {@label}
      </label>
      <textarea id={@id} name={@name || @id} rows={@rows} class={[@base, "px-3.5 py-3"]} {@rest}>{render_slot(@inner_block)}</textarea>
    </div>
    """
  end

  @doc "A native select with the site's look. `options` is a list of strings or {label, value}."
  attr :id, :string, required: true
  attr :name, :string, default: nil
  attr :label, :string, default: nil
  attr :icon, :string, default: nil
  attr :options, :list, required: true
  attr :value, :any, default: nil
  attr :prompt, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(disabled required)

  def select_field(assigns) do
    assigns = assign(assigns, :base, @field_base)

    ~H"""
    <div class={@class}>
      <label :if={@label} for={@id} class="mb-1.5 block text-sm font-semibold text-ink">
        {@label}
      </label>
      <div class="relative">
        <.icon
          :if={@icon}
          name={@icon}
          class="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-ink-faint"
        />
        <select
          id={@id}
          name={@name || @id}
          class={[@base, "h-11 appearance-none pr-10", if(@icon, do: "pl-10", else: "pl-3.5")]}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
        <.icon
          name="hero-chevron-down-mini"
          class="pointer-events-none absolute right-3.5 top-1/2 size-4 -translate-y-1/2 text-ink-soft"
        />
      </div>
    </div>
    """
  end

  @doc "A checkbox with its label."
  attr :id, :string, required: true
  attr :name, :string, default: nil
  attr :label, :string, required: true
  attr :checked, :boolean, default: false
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(value disabled)

  def checkbox(assigns) do
    ~H"""
    <label
      for={@id}
      class={["inline-flex cursor-pointer items-center gap-2.5 text-sm text-ink", @class]}
    >
      <input
        id={@id}
        name={@name || @id}
        type="checkbox"
        checked={@checked}
        class="size-5 shrink-0 cursor-pointer appearance-none rounded-md border border-line bg-surface transition checked:border-brand checked:bg-brand checked:bg-[url('data:image/svg+xml;utf8,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 16 16%22 fill=%22white%22><path d=%22M12.7 4.7a1 1 0 0 1 0 1.4l-5 5a1 1 0 0 1-1.4 0l-2.5-2.5a1 1 0 1 1 1.4-1.4L7 9l4.3-4.3a1 1 0 0 1 1.4 0z%22/></svg>')] checked:bg-center checked:bg-no-repeat focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-brand/25 disabled:opacity-40"
        {@rest}
      />
      {@label}
    </label>
    """
  end

  @doc "A radio button with its label."
  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :checked, :boolean, default: false
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(disabled)

  def radio(assigns) do
    ~H"""
    <label
      for={@id}
      class={["inline-flex cursor-pointer items-center gap-2.5 text-sm text-ink", @class]}
    >
      <input
        id={@id}
        name={@name}
        type="radio"
        value={@value}
        checked={@checked}
        class="size-5 shrink-0 cursor-pointer appearance-none rounded-full border border-line bg-surface transition checked:border-[6px] checked:border-brand focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-brand/25 disabled:opacity-40"
        {@rest}
      />
      {@label}
    </label>
    """
  end

  @doc "An on/off switch."
  attr :id, :string, required: true
  attr :name, :string, default: nil
  attr :label, :string, default: nil
  attr :checked, :boolean, default: false
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(disabled)

  def switch(assigns) do
    ~H"""
    <label
      for={@id}
      class={["inline-flex cursor-pointer items-center gap-3 text-sm text-ink", @class]}
    >
      <input
        id={@id}
        name={@name || @id}
        type="checkbox"
        role="switch"
        checked={@checked}
        class="peer sr-only"
        {@rest}
      />
      <span
        aria-hidden="true"
        class="relative h-6 w-11 shrink-0 rounded-full bg-line transition-colors peer-checked:bg-brand peer-focus-visible:ring-4 peer-focus-visible:ring-brand/25 peer-disabled:opacity-40 after:absolute after:left-0.5 after:top-0.5 after:size-5 after:rounded-full after:bg-white after:shadow-sm after:transition-transform peer-checked:after:translate-x-5"
      >
      </span>
      <span :if={@label}>{@label}</span>
    </label>
    """
  end

  @doc "A range slider with its current value."
  attr :id, :string, required: true
  attr :name, :string, default: nil
  attr :label, :string, default: nil
  attr :min, :integer, default: 0
  attr :max, :integer, default: 100
  attr :value, :integer, default: 50
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(disabled step)

  def slider(assigns) do
    ~H"""
    <div class={@class}>
      <label :if={@label} for={@id} class="mb-1.5 block text-sm font-semibold text-ink">
        {@label}
      </label>
      <div class="flex items-center gap-3">
        <input
          id={@id}
          name={@name || @id}
          type="range"
          min={@min}
          max={@max}
          value={@value}
          class="h-2 w-full cursor-pointer"
          {@rest}
        />
        <output for={@id} class="w-8 text-right text-sm font-semibold tabular-nums text-ink-soft">
          {@value}
        </output>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Navigation
  # ---------------------------------------------------------------------------

  @doc "A tab strip. `items` are labels; the active one is marked `aria-selected`."
  attr :id, :string, required: true
  attr :items, :list, required: true
  attr :active, :string, required: true
  attr :class, :any, default: nil

  def tabs(assigns) do
    ~H"""
    <div
      id={@id}
      role="tablist"
      data-tabs
      class={["inline-flex gap-1 rounded-full bg-muted p-1", @class]}
    >
      <button
        :for={item <- @items}
        type="button"
        role="tab"
        aria-selected={to_string(item == @active)}
        class="rounded-full px-4 py-1.5 text-sm font-semibold text-ink-soft transition-colors hover:text-ink aria-selected:bg-surface aria-selected:text-brand aria-selected:shadow-xs focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-brand/25"
      >
        {item}
      </button>
    </div>
    """
  end

  @doc "A breadcrumb trail. `items` is a list of {label, href}; the last one is the current page."
  attr :items, :list, required: true
  attr :class, :any, default: nil

  def breadcrumb(assigns) do
    assigns = assign(assigns, :count, length(assigns.items))

    ~H"""
    <nav aria-label="Breadcrumb" class={@class}>
      <ol class="flex flex-wrap items-center gap-1.5 text-sm">
        <li class="flex items-center gap-1.5 text-ink-soft">
          <a href="/" class="grid size-6 place-items-center rounded-md hover:bg-muted hover:text-ink">
            <.icon name="hero-home-mini" class="size-4" />
          </a>
        </li>
        <li :for={{{label, href}, i} <- Enum.with_index(@items, 1)} class="flex items-center gap-1.5">
          <.icon name="hero-chevron-right-mini" class="size-4 text-ink-faint" />
          <a
            :if={i < @count}
            href={href}
            class="rounded-md px-1 text-ink-soft hover:bg-muted hover:text-ink"
          >
            {label}
          </a>
          <span :if={i == @count} aria-current="page" class="px-1 font-semibold text-brand">
            {label}
          </span>
        </li>
      </ol>
    </nav>
    """
  end

  @doc "Page numbers with previous and next. Pages are rendered as links to `href_fn.(page)`."
  attr :page, :integer, required: true
  attr :total, :integer, required: true
  attr :href_fn, :any, default: &GameBuddyWeb.SiteComponents.page_href/1
  attr :class, :any, default: nil

  def pagination(assigns) do
    assigns = assign(assigns, :pages, pagination_pages(assigns.page, assigns.total))

    ~H"""
    <nav aria-label="Pagination" class={["flex items-center gap-1", @class]}>
      <a
        href={@href_fn.(max(@page - 1, 1))}
        aria-disabled={to_string(@page == 1)}
        class="grid size-9 place-items-center rounded-lg text-ink-soft hover:bg-muted hover:text-ink aria-disabled:pointer-events-none aria-disabled:opacity-40"
      >
        <.icon name="hero-chevron-left-mini" class="size-4" />
      </a>
      <%= for p <- @pages do %>
        <span :if={p == :gap} class="grid size-9 place-items-center text-ink-faint">…</span>
        <a
          :if={p != :gap}
          href={@href_fn.(p)}
          aria-current={p == @page && "page"}
          class="grid size-9 place-items-center rounded-lg text-sm font-semibold text-ink-soft hover:bg-muted hover:text-ink aria-[current=page]:bg-brand aria-[current=page]:text-white"
        >
          {p}
        </a>
      <% end %>
      <a
        href={@href_fn.(min(@page + 1, @total))}
        aria-disabled={to_string(@page == @total)}
        class="grid size-9 place-items-center rounded-lg text-ink-soft hover:bg-muted hover:text-ink aria-disabled:pointer-events-none aria-disabled:opacity-40"
      >
        <.icon name="hero-chevron-right-mini" class="size-4" />
      </a>
    </nav>
    """
  end

  @doc false
  def page_href(page), do: "?page=#{page}"

  defp pagination_pages(_page, total) when total <= 7, do: Enum.to_list(1..max(total, 1))

  defp pagination_pages(page, total) do
    cond do
      page <= 4 -> [1, 2, 3, 4, 5, :gap, total]
      page >= total - 3 -> [1, :gap, total - 4, total - 3, total - 2, total - 1, total]
      true -> [1, :gap, page - 1, page, page + 1, :gap, total]
    end
  end

  @doc "A vertical menu, as in a sidebar. `items` are {label, icon, href}."
  attr :items, :list, required: true
  attr :active, :string, required: true
  attr :on_dark, :boolean, default: false
  attr :class, :any, default: nil

  def side_nav(assigns) do
    ~H"""
    <nav class={["flex flex-col gap-0.5", @class]}>
      <a
        :for={{label, icon, href} <- @items}
        href={href}
        aria-current={label == @active && "page"}
        class={[
          "flex items-center gap-3 rounded-xl px-3 py-2 text-sm font-semibold transition-colors",
          if(@on_dark,
            do:
              "text-white/70 hover:bg-white/10 hover:text-white aria-[current=page]:bg-brand aria-[current=page]:text-white",
            else:
              "text-ink-soft hover:bg-muted hover:text-ink aria-[current=page]:bg-lavender aria-[current=page]:text-brand-deep"
          )
        ]}
      >
        <.icon name={icon} class="size-4" />
        {label}
      </a>
    </nav>
    """
  end

  # ---------------------------------------------------------------------------
  # Feedback and status
  # ---------------------------------------------------------------------------

  @alert_kinds %{
    "success" => {"bg-mint text-lime-deep", "hero-check-circle"},
    "info" => {"bg-lavender text-brand-deep", "hero-information-circle"},
    "warning" => {"bg-sand text-sun-deep", "hero-exclamation-triangle"},
    "error" => {"bg-blush text-coral-deep", "hero-x-circle"}
  }

  @doc "An inline message. Kinds: success, info, warning, error."
  attr :kind, :string, default: "info", values: Map.keys(@alert_kinds)
  attr :title, :string, required: true
  attr :text, :string, default: nil
  attr :dismissible, :boolean, default: false
  attr :class, :any, default: nil
  attr :rest, :global

  def alert(assigns) do
    assigns = assign(assigns, :spec, Map.fetch!(@alert_kinds, assigns.kind))

    ~H"""
    <div
      role="alert"
      class={["flex items-start gap-3 rounded-2xl px-4 py-3", elem(@spec, 0), @class]}
      {@rest}
    >
      <.icon name={elem(@spec, 1)} class="mt-0.5 size-5 shrink-0" />
      <div class="grow text-sm">
        <p class="font-bold">{@title}</p>
        <p :if={@text} class="mt-0.5 opacity-80">{@text}</p>
      </div>
      <button
        :if={@dismissible}
        type="button"
        data-dismiss="[role=alert]"
        aria-label="Dismiss"
        class="-mr-1 grid size-7 shrink-0 place-items-center rounded-full opacity-60 hover:bg-black/5 hover:opacity-100"
      >
        <.icon name="hero-x-mark-mini" class="size-4" />
      </button>
    </div>
    """
  end

  @doc "A toast: a dark card that floats over the page."
  attr :title, :string, required: true
  attr :text, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global

  def toast(assigns) do
    ~H"""
    <div
      role="status"
      class={["flex w-80 items-start gap-3 rounded-2xl bg-night p-4 text-white shadow-lg", @class]}
      {@rest}
    >
      <.mark size={32} />
      <div class="grow text-sm">
        <p class="font-bold">{@title}</p>
        <p :if={@text} class="mt-0.5 text-white/70">{@text}</p>
      </div>
      <button
        type="button"
        data-dismiss="[role=status]"
        aria-label="Dismiss"
        class="-mr-1 grid size-7 shrink-0 place-items-center rounded-full text-white/60 hover:bg-white/10 hover:text-white"
      >
        <.icon name="hero-x-mark-mini" class="size-4" />
      </button>
    </div>
    """
  end

  @doc "Shows `text` above the content on hover and focus."
  attr :text, :string, required: true
  attr :title, :string, default: nil
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def tooltip(assigns) do
    ~H"""
    <span class={["group relative inline-flex", @class]} tabindex="0">
      {render_slot(@inner_block)}
      <span
        role="tooltip"
        class="pointer-events-none absolute bottom-full left-1/2 z-10 mb-2 w-max max-w-56 -translate-x-1/2 rounded-xl bg-night px-3 py-2 text-left text-xs text-white opacity-0 shadow-lg transition-opacity duration-150 group-hover:opacity-100 group-focus-visible:opacity-100"
      >
        <span :if={@title} class="block font-bold">{@title}</span>
        <span class="block text-white/75">{@text}</span>
        <span class="absolute left-1/2 top-full size-2 -translate-x-1/2 -translate-y-1 rotate-45 bg-night">
        </span>
      </span>
    </span>
    """
  end

  @doc "A progress bar. `value` is 0 to 100."
  attr :value, :integer, required: true
  attr :label, :string, default: nil
  attr :class, :any, default: nil

  def progress(assigns) do
    ~H"""
    <div class={@class}>
      <div :if={@label} class="mb-1.5 flex justify-between text-xs font-semibold">
        <span class="text-ink">{@label}</span>
        <span class="tabular-nums text-ink-soft">{@value}%</span>
      </div>
      <div
        role="progressbar"
        aria-valuenow={@value}
        aria-valuemin="0"
        aria-valuemax="100"
        class="h-2 overflow-hidden rounded-full bg-muted"
      >
        <div class="h-full rounded-full bg-brand transition-[width]" style={"width: #{@value}%"}>
        </div>
      </div>
    </div>
    """
  end

  @doc "Placeholder blocks shown while content loads."
  attr :lines, :integer, default: 3
  attr :avatar, :boolean, default: false
  attr :class, :any, default: nil

  def skeleton(assigns) do
    ~H"""
    <div class={["flex gap-3 motion-safe:animate-pulse", @class]} aria-hidden="true">
      <div :if={@avatar} class="size-10 shrink-0 rounded-full bg-muted"></div>
      <div class="grow space-y-2 py-1">
        <div
          :for={i <- 1..@lines}
          class={["h-3 rounded-full bg-muted", rem(i, 3) == 0 && "w-1/2", rem(i, 3) == 2 && "w-5/6"]}
        >
        </div>
      </div>
    </div>
    """
  end

  @doc "A dialog, shown inline so the design system can display it. Real dialogs wrap it in `<dialog>`."
  attr :title, :string, required: true
  attr :text, :string, default: nil
  attr :class, :any, default: nil
  slot :inner_block
  slot :actions

  def dialog_card(assigns) do
    ~H"""
    <div
      role="dialog"
      aria-labelledby="dialog-title"
      class={["w-full max-w-sm rounded-3xl bg-surface p-6 shadow-lg ring-1 ring-line/80", @class]}
    >
      <div class="flex items-start justify-between gap-4">
        <h3 id="dialog-title" class="text-h5 text-ink">{@title}</h3>
        <button
          type="button"
          aria-label="Close"
          class="-mr-2 -mt-1 grid size-8 place-items-center rounded-full text-ink-soft hover:bg-muted hover:text-ink"
        >
          <.icon name="hero-x-mark-mini" class="size-5" />
        </button>
      </div>
      <p :if={@text} class="mt-1.5 text-sm text-ink-soft">{@text}</p>
      <div :if={@inner_block != []} class="mt-4">{render_slot(@inner_block)}</div>
      <div :if={@actions != []} class="mt-6 flex justify-end gap-2">{render_slot(@actions)}</div>
    </div>
    """
  end

  @doc "The closing call to action: a dark panel with the mascot, as a card or a full-width band."
  attr :eyebrow, :string, default: nil
  attr :title, :string, required: true
  attr :text, :string, default: nil
  attr :class, :any, default: nil
  attr :bleed, :boolean, default: false, doc: "full-width band instead of a rounded card"
  attr :rest, :global
  slot :actions

  def cta_banner(assigns) do
    ~H"""
    <.night_panel class={@class} bleed={@bleed} {@rest}>
      <div class={[
        "flex flex-col gap-8 lg:flex-row lg:items-center lg:justify-between",
        if(@bleed, do: "mx-auto w-full max-w-6xl px-4 py-16 sm:px-6 sm:py-20", else: "p-8 sm:p-12")
      ]}>
        <div class="max-w-xl">
          <.eyebrow :if={@eyebrow} on_dark class="mb-3">{@eyebrow}</.eyebrow>
          <h2 class="text-balance text-h2 text-white">{@title}</h2>
          <p :if={@text} class="mt-3 text-lead text-white/70">{@text}</p>
          <div :if={@actions != []} class="mt-7 flex flex-wrap gap-3">{render_slot(@actions)}</div>
        </div>
        <div class="relative shrink-0 self-center lg:mr-8">
          <div class="absolute -right-4 -top-6 rounded-2xl rounded-bl-md bg-white px-3 py-2 text-xs font-semibold text-night shadow-md">
            Ask me anything.
          </div>
          <.mascot expression="excited" class="size-36 sm:size-44" />
        </div>
      </div>
    </.night_panel>
    """
  end
end

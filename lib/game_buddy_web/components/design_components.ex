defmodule GameBuddyWeb.DesignComponents do
  @moduledoc """
  Scaffolding for the `/design` page: its sections, examples with their usage, swatches,
  and the token tables the page documents. The tokens themselves live in
  `assets/css/app.css`; the tables here only describe them.
  """
  use Phoenix.Component

  @sections [
    {"brand", "Brand"},
    {"mascot", "Mascot"},
    {"illustration", "Illustration"},
    {"color", "Color"},
    {"typography", "Typography"},
    {"buttons", "Buttons"},
    {"forms", "Forms"},
    {"navigation", "Navigation"},
    {"feedback", "Feedback"},
    {"cards", "Cards"},
    {"patterns", "Patterns"},
    {"foundations", "Foundations"},
    {"layout", "Layout"}
  ]

  @doc "The page's sections as {id, label}, in order; the left nav and the numbering follow it."
  def sections, do: @sections

  @doc "Color groups: {group, [{name, token, hex, use}]}."
  def palette do
    [
      {"Brand",
       [
         {"Violet", "brand", "#6c4dff", "Primary actions, links, the mark"},
         {"Periwinkle", "brand-soft", "#8b9cff", "Accents on dark, highlighted words"},
         {"Indigo", "brand-deep", "#2d286f", "Text on lavender, shadows' tint"}
       ]},
      {"Night",
       [
         {"Night", "night", "#15133a", "Dark panels: hero, demo, call to action"},
         {"Night 2", "night-2", "#1f1c55", "Gradient partner of night"},
         {"Night 3", "night-3", "#2a2770", "Raised surfaces on night"}
       ]},
      {"Accent",
       [
         {"Coral", "coral", "#ff6b8b", "Destructive, errors, one tile in four"},
         {"Lime", "lime", "#a6f45b", "Success, live status"},
         {"Sun", "sun", "#ffc857", "Warnings, one tile in four"}
       ]},
      {"Soft",
       [
         {"Lavender", "lavender", "#e9e7ff", "Secondary buttons, violet tags, buddy bubbles"},
         {"Mint", "mint", "#e6f9eb", "Success fills"},
         {"Sand", "sand", "#fff4d6", "Warning fills"},
         {"Blush", "blush", "#ffe9ee", "Error fills"}
       ]},
      {"Neutral",
       [
         {"Canvas", "canvas", "#fafafc", "Page background"},
         {"Surface", "surface", "#ffffff", "Cards, fields, header"},
         {"Muted", "muted", "#f1f2f7", "Hover fills, code blocks, tab strips"},
         {"Line", "line", "#e3e5f0", "Borders and rings"},
         {"Ink", "ink", "#0f172a", "Text"},
         {"Ink soft", "ink-soft", "#647488", "Secondary text"},
         {"Ink faint", "ink-faint", "#9aa7b8", "Placeholders, disabled"}
       ]}
    ]
  end

  @doc "The type scale: {name, class, size and line height, weight, tracking, sample}."
  def type_scale do
    [
      {"H1", "text-h1", "56 / 1.06", "800", "-0.03em", "Know the game like it knows itself."},
      {"H2", "text-h2", "40 / 1.1", "800", "-0.025em", "Exact knowledge for every playstyle."},
      {"H3", "text-h3", "32 / 1.2", "700", "-0.02em", "Answers that cite the files."},
      {"H4", "text-h4", "24 / 1.3", "700", "-0.015em", "Built for a deeper game."},
      {"H5", "text-h5", "20 / 1.4", "600", "-0.01em", "Mechanics and rules"},
      {"Lead", "text-lead", "18 / 1.6", "400", "0",
       "Every fact comes from the game's own files."},
      {"Body", "text-base", "16 / 1.5", "400", "0", "Search games, entities or mechanics."},
      {"Small", "text-sm", "14 / 1.43", "400", "0", "Exact, current, cited."},
      {"Caption", "text-xs", "12 / 1.33", "600", "0", "Updated 5 min ago"}
    ]
  end

  @doc "Spacing steps in pixels (Tailwind's 4px grid)."
  def spacing, do: [4, 8, 12, 16, 24, 32, 48, 64]

  @doc "Corner radii: {class, pixels, use}."
  def radii do
    [
      {"rounded-md", "6", "Chips, kbd"},
      {"rounded-lg", "8", "Small tiles"},
      {"rounded-xl", "12", "Fields, tiles, menu items"},
      {"rounded-2xl", "16", "Alerts, bubbles, toasts"},
      {"rounded-3xl", "24", "Cards"},
      {"rounded-[2rem]", "32", "Night panels"},
      {"rounded-full", "pill", "Buttons, pills, search"}
    ]
  end

  @doc "Shadow tokens: {class, use}."
  def shadows do
    [
      {"shadow-xs", "Cards at rest"},
      {"shadow-sm", "Buttons, fields"},
      {"shadow-md", "Hovered buttons, floating tiles"},
      {"shadow-lg", "Toasts, dialogs, tooltips"}
    ]
  end

  @doc "Icons the site uses most, to show the style."
  def icon_sample do
    ~w(hero-home hero-magnifying-glass hero-book-open hero-cube hero-sparkles hero-bolt hero-map
       hero-users hero-cog-6-tooth hero-puzzle-piece hero-globe-europe-africa hero-shield-check
       hero-link hero-play hero-arrow-right hero-check-circle)
  end

  @doc "Illustrations under priv/static/images/site: {file, name, use}."
  def illustrations do
    [
      {"island-portal.webp", "Portal island", "Connecting: the first step of how it works"},
      {"island-garden.webp", "Garden island", "Asking: a path through the game's documents"},
      {"island-castle.webp", "Castle island",
       "Arriving: the answer, and the closing call to action"},
      {"valley.webp", "Valley", "A background under a night gradient, never bare"}
    ]
  end

  @doc "One documented section with its number, title and introduction."
  attr :id, :string, required: true
  attr :number, :string, required: true
  attr :title, :string, required: true
  attr :text, :string, default: nil
  slot :inner_block, required: true

  def ds_section(assigns) do
    ~H"""
    <section id={@id} class="scroll-mt-32 lg:scroll-mt-28" aria-labelledby={"#{@id}-title"}>
      <div class="mb-8 max-w-2xl">
        <p class="font-mono text-xs font-bold text-brand">{@number}</p>
        <h2 id={"#{@id}-title"} class="mt-1 text-h3 text-ink">{@title}</h2>
        <p :if={@text} class="mt-3 text-pretty text-base text-ink-soft">{@text}</p>
      </div>
      <div class="space-y-6">
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  @doc "A framed example with its title, a note and the HEEx that produces it."
  attr :title, :string, required: true
  attr :text, :string, default: nil
  attr :code, :string, default: nil
  attr :dark, :boolean, default: false
  attr :class, :any, default: nil
  attr :body_class, :any, default: nil
  slot :inner_block, required: true

  def example(assigns) do
    ~H"""
    <div class={["overflow-hidden rounded-3xl bg-surface shadow-xs ring-1 ring-line/80", @class]}>
      <div class="border-b border-line px-5 py-3">
        <h3 class="text-sm font-bold text-ink">{@title}</h3>
        <p :if={@text} class="mt-0.5 text-xs text-ink-soft">{@text}</p>
      </div>
      <div class={["p-6", @dark && "bg-night text-white", @body_class]}>
        {render_slot(@inner_block)}
      </div>
      <pre
        :if={@code}
        class="overflow-x-auto border-t border-line bg-muted/60 px-5 py-3 font-mono text-xs leading-relaxed text-ink-soft"
      ><code>{@code}</code></pre>
    </div>
    """
  end

  @doc "A color swatch with its name, token and hex."
  attr :name, :string, required: true
  attr :token, :string, required: true
  attr :hex, :string, required: true
  attr :text, :string, default: nil

  def swatch(assigns) do
    ~H"""
    <div class="min-w-0">
      <div
        class="aspect-[4/3] rounded-2xl ring-1 ring-inset ring-black/5"
        style={"background: #{@hex}"}
      >
      </div>
      <p class="mt-2 text-sm font-bold text-ink">{@name}</p>
      <p class="font-mono text-[11px] text-ink-soft">{@hex} · {@token}</p>
      <p :if={@text} class="mt-0.5 text-xs text-ink-soft">{@text}</p>
    </div>
    """
  end

  @doc "A label under a specimen."
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def caption(assigns) do
    ~H"""
    <p class={["text-xs font-semibold text-ink-soft", @class]}>{render_slot(@inner_block)}</p>
    """
  end
end

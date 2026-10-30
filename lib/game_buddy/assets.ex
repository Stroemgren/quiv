defmodule GameBuddy.Assets do
  @moduledoc """
  Textures from the game files, converted for the interactive view: the entity
  icons the adapter resolved at ingest (stored on each document's `sections`)
  and the theme the adapter declares (font families, text colors read from the
  game's text formatting file, color roles sampled from its flat color
  textures, frame textures with the 9-slice borders its GUI uses). Everything
  is stored per snapshot in `assets` and served by `show` as data URIs.

  Conversion runs `priv/scripts/convert_textures.py` (Python 3 with Pillow,
  which decodes the engine's DDS textures); `mix game.assets` drives it.
  """
  import Ecto.Query
  require Logger
  alias GameBuddy.{Adapter, Repo}

  @script "priv/scripts/convert_textures.py"
  @icon_max 96
  @small_icon_max 48
  @theme_path "theme"

  @doc "Stored assets for the given paths: `%{path => {mime, binary}}`."
  def fetch(_gv_id, []), do: %{}

  def fetch(gv_id, paths) do
    Repo.all(
      from a in "assets",
        where: a.game_version_id == ^gv_id and a.path in ^paths,
        select: {a.path, {a.mime, a.data}}
    )
    |> Map.new()
  end

  @doc "The snapshot's theme, or nil before `mix game.assets` ran."
  def theme(gv_id) do
    case fetch(gv_id, [@theme_path]) do
      %{@theme_path => {_mime, json}} -> Jason.decode!(json)
      _ -> nil
    end
  end

  def data_uri(mime, data), do: "data:#{mime};base64," <> Base.encode64(data)

  @doc """
  Convert and store every texture a snapshot needs: the icons its documents
  name and the adapter's theme. Textures already stored are skipped; the theme
  is rebuilt each run.
  """
  def build(gv, root) do
    adapter = Adapter.for_version(gv)
    roots = Adapter.gfx_roots(adapter, root)
    decl = Adapter.theme(adapter)
    rk = Adapter.render_kinds(adapter)
    stored = stored_paths(gv.id)

    icons =
      for {kind, path} <- icon_paths(gv.id), path not in stored do
        %{path: path, max: if(kind == rk.modifiers, do: @small_icon_max, else: @icon_max)}
      end

    textures =
      for {_role, t} <- decl["textures"] || %{}, t["path"] not in stored do
        %{
          path: t["path"],
          max: t["max"],
          lossless: is_nil(t["max"]),
          tint: t["tint"],
          alpha: t["alpha"]
        }
      end

    samples = for {_role, path} <- decl["colors"] || %{}, do: %{path: path, sample: true}

    results = convert(roots, icons ++ textures ++ samples)
    {errors, ok} = Enum.split_with(results, &Map.has_key?(&1, "error"))
    Enum.each(errors, &Logger.warning("asset #{&1["path"]}: #{&1["error"]}"))
    {colors, images} = Enum.split_with(ok, &Map.has_key?(&1, "hex"))
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    rows =
      for r <- images do
        %{
          game_version_id: gv.id,
          path: r["path"],
          mime: "image/webp",
          width: r["width"],
          height: r["height"],
          data: File.read!(r["out"]),
          inserted_at: now
        }
      end

    rows |> Enum.chunk_every(200) |> Enum.each(&store/1)
    Enum.each(images, &File.rm(&1["out"]))
    images |> Enum.map(&Path.dirname(&1["out"])) |> Enum.uniq() |> Enum.each(&File.rm_rf/1)

    theme = theme_json(decl, root, colors)

    store([
      %{
        game_version_id: gv.id,
        path: @theme_path,
        mime: "application/json",
        data: Jason.encode!(theme),
        inserted_at: now
      }
    ])

    %{
      icons: length(icons),
      textures: length(textures),
      stored: length(rows),
      errors: length(errors),
      theme: theme
    }
  end

  defp store(rows),
    do:
      Repo.insert_all("assets", rows,
        on_conflict: {:replace, [:mime, :width, :height, :data, :inserted_at]},
        conflict_target: [:game_version_id, :path]
      )

  defp stored_paths(gv_id) do
    Repo.all(from a in "assets", where: a.game_version_id == ^gv_id, select: a.path)
    |> MapSet.new()
  end

  # Every icon path a document of the snapshot names, with its kind.
  defp icon_paths(gv_id) do
    Repo.all(
      from d in "documents",
        where: d.game_version_id == ^gv_id and not is_nil(fragment("?->>'icon'", d.sections)),
        distinct: true,
        select: {d.kind, fragment("?->>'icon'", d.sections)}
    )
  end

  # -- conversion -------------------------------------------------------------

  defp convert(_roots, []), do: []

  defp convert(roots, entries) do
    tmp = Path.join(System.tmp_dir!(), "game_buddy_assets_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)

    {items, missing} =
      entries
      |> Enum.with_index()
      |> Enum.map(fn {e, i} ->
        %{
          path: e.path,
          src: resolve(roots, e.path),
          out: Path.join(tmp, "#{i}.webp"),
          max: e[:max],
          lossless: e[:lossless] || false,
          tint: e[:tint] && resolve(roots, e[:tint]),
          alpha: e[:alpha],
          sample: e[:sample] || false
        }
      end)
      |> Enum.split_with(& &1.src)

    if missing != [],
      do: Logger.warning("#{length(missing)} textures not found, e.g. #{hd(missing).path}")

    manifest = Path.join(tmp, "manifest.json")
    File.write!(manifest, Jason.encode!(items))
    script = Application.app_dir(:game_buddy, @script)

    case System.cmd("python3", ["-I", script, manifest], stderr_to_stdout: false) do
      {out, 0} ->
        Jason.decode!(out)

      {out, code} ->
        raise "convert_textures.py failed (#{code}); needs python3 with Pillow: #{String.slice(out, 0, 500)}"
    end
  end

  # The first gfx root under which a relative texture path exists.
  defp resolve(roots, rel) when is_binary(rel),
    do:
      Enum.find_value(roots, fn r ->
        p = Path.join(r, rel)
        File.regular?(p) && p
      end)

  defp resolve(_roots, _), do: nil

  # -- theme ------------------------------------------------------------------

  defp theme_json(decl, root, colors) do
    tf = decl["text_formats"] || %{}

    text =
      if tf["file"],
        do: text_colors(Path.join(root, tf["file"]), tf["roles"] || %{}),
        else: %{}

    color_roles =
      for {role, path} <- decl["colors"] || %{},
          hex = Enum.find_value(colors, &(&1["path"] == path && &1["hex"])),
          into: %{},
          do: {role, hex}

    textures =
      for {role, t} <- decl["textures"] || %{}, into: %{} do
        {role, %{"asset" => t["path"], "slice" => t["slice"], "density" => t["density"] || 1}}
      end

    %{
      "fonts" => decl["fonts"] || %{},
      "text" => text,
      "colors" => color_roles,
      "textures" => textures
    }
  end

  @doc """
  Colors named in a Jomini text formatting file (`name = color_x` followed by
  `format = "color:{r,g,b}"`), taken from the blocks that are not color-blind
  variants, as `%{role => "#rrggbb"}` for the given `%{role => name}`.
  """
  def text_colors(file, roles) do
    case File.read(file) do
      {:ok, text} ->
        body =
          text
          |> String.split(~r/textformatting\s*=\s*\{/)
          |> Enum.reject(&String.contains?(&1, "color_blind_mode"))
          |> Enum.join("\n")

        for {role, name} <- roles, hex = color_in(body, name), into: %{}, do: {role, hex}

      _ ->
        %{}
    end
  end

  defp color_in(body, name) do
    re =
      ~r/name\s*=\s*"?#{Regex.escape(name)}"?\s*\n\s*format\s*=\s*"color:\{\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)/

    case Regex.run(re, body) do
      [_, r, g, b] -> "#" <> Enum.map_join([r, g, b], "", &channel/1)
      _ -> nil
    end
  end

  defp channel(s) do
    {f, _} = Float.parse(s)

    (f * 255)
    |> round()
    |> min(255)
    |> max(0)
    |> Integer.to_string(16)
    |> String.pad_leading(2, "0")
    |> String.downcase()
  end
end

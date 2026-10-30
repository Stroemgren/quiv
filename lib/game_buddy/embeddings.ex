defmodule GameBuddy.Embeddings do
  @moduledoc """
  Local sentence embeddings with Bumblebee: `BAAI/bge-small-en-v1.5`, 384 dims,
  CLS pooling, L2-normalised (cosine distance = 1 - dot product).

  The serving is started in the supervision tree when
  `config :game_buddy, :embeddings, enabled: true`. The model is downloaded to
  the Bumblebee cache on first use. The Nx backend and defn compiler come from
  `config :nx` (EMLX on macOS, EXLA elsewhere; see `config/config.exs`).
  """

  @model "BAAI/bge-small-en-v1.5"
  @dims 384
  @name GameBuddy.Embeddings.Serving

  def dims, do: @dims
  def model, do: @model
  def name, do: @name

  def enabled?, do: Application.get_env(:game_buddy, :embeddings, [])[:enabled] == true
  def available?, do: Process.whereis(@name) != nil

  @doc "Child spec for the supervision tree."
  def child_spec(opts) do
    batch_size = Keyword.get(opts, :batch_size, 32)

    %{
      id: @name,
      start:
        {Nx.Serving, :start_link,
         [[serving: serving(batch_size), name: @name, batch_size: batch_size, batch_timeout: 50]]},
      type: :worker
    }
  end

  @doc "Build the Bumblebee serving."
  def serving(batch_size \\ 32) do
    {:ok, model_info} = Bumblebee.load_model({:hf, @model})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, @model})

    Bumblebee.Text.text_embedding(model_info, tokenizer,
      output_attribute: :hidden_state,
      output_pool: :cls_token_pooling,
      embedding_processor: :l2_norm,
      compile: [batch_size: batch_size, sequence_length: 256],
      defn_options: Nx.Defn.default_options()
    )
  end

  @doc "Embed a list of texts. Returns a list of float lists."
  def embed(texts) when is_list(texts) do
    @name
    |> Nx.Serving.batched_run(texts)
    |> Enum.map(fn %{embedding: e} -> Nx.to_flat_list(e) end)
  end

  def embed_one(text) when is_binary(text), do: texts_or_raise([text]) |> hd()

  defp texts_or_raise(texts) do
    unless available?(),
      do:
        raise("embedding serving is not running (config :game_buddy, :embeddings, enabled: true)")

    embed(texts)
  end
end

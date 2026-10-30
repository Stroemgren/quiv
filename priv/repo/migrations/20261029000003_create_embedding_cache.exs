defmodule GameBuddy.Repo.Migrations.CreateEmbeddingCache do
  use Ecto.Migration

  # Embeddings keyed by the md5 of the chunk text, so a re-ingest only has to
  # embed chunks whose text actually changed.
  def change do
    create table(:embedding_cache, primary_key: false) do
      add :hash, :text, primary_key: true
      add :embedding, :vector, size: 384, null: false
    end
  end
end

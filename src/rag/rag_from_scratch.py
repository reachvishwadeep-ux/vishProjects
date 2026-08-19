import os

dataset = []
EMBEDDING_MODEL = 'hf.co/CompendiumLabs/bge-base-en-v1.5-gguf'
LANGUAGE_MODEL = 'hf.co/bartowski/Llama-3.2-1B-Instruct-GGUF'
VECTOR_DB = []
ollama = None

def _get_ollama():
  global ollama
  if ollama is None:
    import ollama as ollama_module
    ollama = ollama_module
  return ollama

def add_chunks_to_vector_db(chunks):
    embedding = _get_ollama().embed(
        model=EMBEDDING_MODEL, input=chunks
    )['embeddings'][0]
    VECTOR_DB.append((chunks,embedding))

def cosine_similarity(a, b):
  dot_product = sum([x * y for x, y in zip(a, b)])
  norm_a = sum([x ** 2 for x in a]) ** 0.5
  norm_b = sum([x ** 2 for x in b]) ** 0.5
  return dot_product / (norm_a * norm_b)

def retrieve(query, top_n=1):
  query_embedding = _get_ollama().embed(
      model=EMBEDDING_MODEL, input=query
  )['embeddings'][0]
  similarities = []
  for chunk, embedding in VECTOR_DB:
    similarity = cosine_similarity(query_embedding, embedding)
    similarities.append((chunk, similarity))
  similarities.sort(key=lambda x: x[1], reverse=True)
  return similarities[:top_n]

def _run_demo():
  file_path = os.path.join(os.path.dirname(__file__), 'cat-facts.txt')
  try:
    with open(file_path, 'r', encoding='utf-8') as file:
      dataset.extend(file.readlines())
  except UnicodeDecodeError:
    with open(file_path, 'r', encoding='utf-8', errors='replace') as file:
      dataset.extend(file.readlines())

  print(f"Loaded {len(dataset)} lines from {file_path}")
  for chunk in dataset:
    add_chunks_to_vector_db(chunk)
  print(retrieve("What do cats eat?"))


if __name__ == "__main__":
  _run_demo()

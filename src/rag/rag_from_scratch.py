import os

#1. create dataset
dataset = []
file_path = os.path.join(os.path.dirname(__file__), 'cat-facts.txt')

try:
    with open(file_path, 'r', encoding='utf-8') as file:
        dataset = file.readlines()
except UnicodeDecodeError:
    # Fallback for files saved in Windows/local encodings.
    with open(file_path, 'r', encoding='utf-8', errors='replace') as file:
        dataset = file.readlines()

print(f"Loaded {len(dataset)} lines from {file_path}")

#2. create chunks, embed and store in vector database in memory

import ollama
EMBEDDING_MODEL = 'hf.co/CompendiumLabs/bge-base-en-v1.5-gguf'
LANGUAGE_MODEL = 'hf.co/bartowski/Llama-3.2-1B-Instruct-GGUF'

VECTOR_DB=[]
def add_chunks_to_vector_db(chunks):
    embedding = ollama.embed(model=EMBEDDING_MODEL,input=chunks)['embeddings'][0]
    VECTOR_DB.append((chunks,embedding))

#consider each line in the dataset as a chunk for simplicity.
for i, chunk in enumerate(dataset):
  add_chunks_to_vector_db(chunk)
  #print(f'Added chunk {i+1}/{len(dataset)} to the database')

#3. define cosine similarity function to retrieve relevant chunks based on query embedding
def cosine_similarity(a, b):
  dot_product = sum([x * y for x, y in zip(a, b)])
  norm_a = sum([x ** 2 for x in a]) ** 0.5
  norm_b = sum([x ** 2 for x in b]) ** 0.5
  return dot_product / (norm_a * norm_b)

#4. retrieve relevant chunks based on query

def retrieve(query, top_n=1):
  query_embedding = ollama.embed(model=EMBEDDING_MODEL, input=query)['embeddings'][0]
  # temporary list to store (chunk, similarity) pairs
  similarities = []
  for chunk, embedding in VECTOR_DB:
    similarity = cosine_similarity(query_embedding, embedding)
    similarities.append((chunk, similarity))
  # sort by similarity in descending order, because higher similarity means more relevant chunks
  similarities.sort(key=lambda x: x[1], reverse=True)
  # finally, return the top N most relevant chunks
  return similarities[:top_n]

#5. Test now
print(retrieve("What do cats eat?"))

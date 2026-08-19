import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import ollama

from common.similarity import top_matches
from common.text_utils import read_lines

#1. create dataset
file_path = Path(__file__).resolve().parent / 'cat-facts.txt'
dataset = read_lines(file_path)

print(f"Loaded {len(dataset)} lines from {file_path}")

#2. create chunks, embed and store in vector database in memory

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

#3. retrieve relevant chunks based on query

def retrieve(query, top_n=1):
  query_embedding = ollama.embed(model=EMBEDDING_MODEL, input=query)['embeddings'][0]
  return top_matches(query_embedding, VECTOR_DB, top_n=top_n)

#4. Test now
print(retrieve("What do cats eat?"))

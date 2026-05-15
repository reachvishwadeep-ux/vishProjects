from openai import OpenAI
import numpy as np
from sklearn.metrics.pairwise import cosine_similarity
from dotenv import load_dotenv
# -----------------------------------
# OpenAI Client
# -----------------------------------
load_dotenv()
client = OpenAI()
    

# -----------------------------------
# Sample Document
# -----------------------------------

text = """
Artificial intelligence is transforming software engineering.
Large language models can generate code, summarize text,
and automate workflows.

Vector databases are used to store embeddings for semantic search.
Embeddings convert text into numerical vectors.

AWS provides cloud infrastructure for scalable AI systems.
DevOps teams use Kubernetes and Terraform for automation.

Monitoring and observability are critical for production AI systems.
Logging, tracing, and metrics help detect failures quickly.
"""

# -----------------------------------
# Chunking Function
# chunk_size = 500
# overlap = 100
# -----------------------------------

def chunk_text(text, chunk_size=500, overlap=100):

    chunks = []

    start = 0

    while start < len(text):

        end = start + chunk_size

        chunk = text[start:end]

        chunks.append(chunk)

        start += chunk_size - overlap

    return chunks

chunks = chunk_text(text)

print("\n--- CHUNKS ---")

for i, chunk in enumerate(chunks):
    print(f"\nChunk {i}")
    print(chunk)

# -----------------------------------
# Generate Embeddings
# -----------------------------------

def get_embeddings(text_chunks):

    response = client.embeddings.create(
        model="text-embedding-3-small",
        input=text_chunks
    )

    return [item.embedding for item in response.data]

embeddings = get_embeddings(chunks)

# -----------------------------------
# Store Vector Index In Memory
# -----------------------------------

vector_store = []

for i, chunk in enumerate(chunks):

    vector_store.append({
        "text": chunk,
        "embedding": embeddings[i]
    })

# -----------------------------------
# Semantic Search Function
# -----------------------------------

def semantic_search(query, top_k=3):

    # Create query embedding
    response = client.embeddings.create(
        model="text-embedding-3-small",
        input=[query]
    )

    query_embedding = response.data[0].embedding

    # Compute similarities
    results = []

    for item in vector_store:

        similarity = cosine_similarity(
            [query_embedding],
            [item["embedding"]]
        )[0][0]

        results.append({
            "text": item["text"],
            "score": similarity
        })

    # Sort descending
    results = sorted(
        results,
        key=lambda x: x["score"],
        reverse=True
    )

    return results[:top_k]

# -----------------------------------
# Example Query
# -----------------------------------

query = "How do embeddings help semantic search?"

results = semantic_search(query)

print("\n--- SEARCH RESULTS ---")

for r in results:

    print("\nScore:", round(r["score"], 4))
    print(r["text"])
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common.openai_utils import embed_text, embed_texts
from common.similarity import top_matches
from common.text_utils import chunk_text

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
# Chunking
# chunk_size = 500
# overlap = 100
# -----------------------------------

chunks = chunk_text(text)

print("\n--- CHUNKS ---")

for i, chunk in enumerate(chunks):
    print(f"\nChunk {i}")
    print(chunk)

# -----------------------------------
# Store Vector Index In Memory as (text, embedding) pairs
# -----------------------------------

vector_store = list(zip(chunks, embed_texts(chunks)))

# -----------------------------------
# Semantic Search Function
# -----------------------------------

def semantic_search(query, top_k=3):
    return top_matches(embed_text(query), vector_store, top_n=top_k)

# -----------------------------------
# Example Query
# -----------------------------------

query = "How do embeddings help semantic search?"

results = semantic_search(query)

print("\n--- SEARCH RESULTS ---")

for chunk, score in results:

    print("\nScore:", round(score, 4))
    print(chunk)

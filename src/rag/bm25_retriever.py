from langchain_classic.retrievers import BM25Retriever
from langchain_core.documents import Document

# Sample corpus
docs = [
    Document(page_content="BM25 is a ranking function used for information retrieval."),
    Document(page_content="BM25 considers term frequency and document length."),
    Document(page_content="Dense retrievers use embeddings to find semantically similar documents."),
    Document(page_content="Retrieval is a critical step in building a chatbot or question-answering system."),
    Document(page_content="Sparse retrievers like BM25 are keyword-based and interpretable.")
]

# Create a BM25 retriever and load documents
retriever = BM25Retriever.from_documents(docs)

# Set how many top documents to return
retriever.k = 3

# Query example
query = "how does bm25 work for retrieval"

# Retrieve relevant documents
results = retriever.invoke({"query": query})
# Display the results
print("Top Retrieved Documents:\n")
for i, doc in enumerate(results, 1):
    print(f"{i}. {doc.page_content}\n")
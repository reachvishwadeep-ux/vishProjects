from langchain_core.documents import Document
from langchain_community.retrievers import BM25Retriever
from langchain_community.vectorstores import Chroma
from langchain_openai import OpenAIEmbeddings
from langchain_classic.retrievers import EnsembleRetriever
from dotenv import load_dotenv
load_dotenv()

# 1. Sample documents
docs = [
    Document(
        page_content="Oracle RMAN backup failed due to snapshot timeout.",
        metadata={"product": "oracle", "severity": "critical", "env": "prod"}
    ),
    Document(
        page_content="AWS Lambda processes S3 file upload events.",
        metadata={"product": "aws", "severity": "medium", "env": "prod"}
    ),
    Document(
        page_content="Database restore was delayed because of storage latency.",
        metadata={"product": "oracle", "severity": "high", "env": "stage"}
    ),
]

# 2. Keyword retriever: BM25
bm25_retriever = BM25Retriever.from_documents(docs)
bm25_retriever.k = 3

# 3. Vector retriever: semantic search
vectorstore = Chroma.from_documents(
    documents=docs,
    embedding=OpenAIEmbeddings()
)

vector_retriever = vectorstore.as_retriever(
    search_kwargs={
        "k": 3,
        "filter": {"env": "prod"}   # metadata filtering
    }
)
# 4. Hybrid retriever: combine keyword + vector
hybrid_retriever = EnsembleRetriever(
    retrievers=[bm25_retriever, vector_retriever],
    weights=[0.4, 0.6]
)

# 5. Search
query = "critical oracle backup failure"

results = hybrid_retriever.invoke(query)

for doc in results:
    print(doc.page_content)
    print(doc.metadata)
    print("---")
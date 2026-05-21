from langchain_community.document_loaders import WebBaseLoader
from langchain_core.vectorstores import InMemoryVectorStore
from langchain_openai import OpenAIEmbeddings
from langchain_text_splitters import RecursiveCharacterTextSplitter
from dotenv import load_dotenv
import os

load_dotenv()

#os.environ.setdefault("USER_AGENT", "vishProjects-rag-eval/1.0")

# List of URLs to load documents from
urls = [
    "https://lilianweng.github.io/posts/2023-06-23-agent/",
    "https://lilianweng.github.io/posts/2023-03-15-prompt-engineering/",
    "https://lilianweng.github.io/posts/2023-10-25-adv-attack-llm/",
]

#load documents from the urls
docs = [WebBaseLoader(url).load() for url in urls]
docs_list = [item for sublist in docs for item in sublist]

# Initialize a text splitter with specified chunk size and overlap. 
# use RecursiveCharacterTextSplitter
# this Helps keep chunks near your target chunk_size 
# while preserving readable boundaries when possible.
text_splitter = RecursiveCharacterTextSplitter.from_tiktoken_encoder(
    chunk_size=250, chunk_overlap=0
)


doc_splits = text_splitter.split_documents(docs_list)
#print first split to verify
#print(doc_splits[0])

#add chunks to InMemoryVectorStore
vectorstore = InMemoryVectorStore.from_documents(documents=doc_splits,
                                                  embedding=OpenAIEmbeddings())

#create retriever from vectorstore
retriever = vectorstore.as_retriever(k=6)
#print(retriever.invoke("What are the different types of agents?"))


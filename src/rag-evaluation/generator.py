from langchain_openai import ChatOpenAI
from langsmith import traceable
import retriever

llm = ChatOpenAI(model="gpt-5.4", temperature=1)

@traceable
def rag_bot(question: str) -> dict:

    #get context from retriever
    docs = retriever.retriever.invoke(question)
    docs_text = "\n\n".join([doc.page_content for doc in docs])

    prompt = f""" You are a helpful assistant who is good at analyzing source information and answering questions.
       Use the following source documents to answer the user's questions.
       If you don't know the answer, just say that you don't know.
       Use three sentences maximum and keep the answer concise.

        Documents:{docs_text }"""
    
    # invoke LLM. It will be traced by Langsmith.

    message = llm.invoke([{"role": "system", "content": prompt},
                        {"role": "user", "content": question}])
    
    return {"answers:":message.content, "documents":docs}








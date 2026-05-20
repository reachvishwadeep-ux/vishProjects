#pip install pymupdf langchain-text-splitters openai

# pip install pymupdf langchain-text-splitters openai

import fitz  # PyMuPDF
from langchain_text_splitters import RecursiveCharacterTextSplitter

PDF_PATH = "my_document.pdf"

splitter = RecursiveCharacterTextSplitter(
    chunk_size=800,
    chunk_overlap=100,
    separators=["\n\n", "\n", ". ", " ", ""]
)

def caption_image(image_bytes: bytes) -> str:
    """
    Replace this with a vision model call.
    Example: GPT-4.1 vision / GPT-4o / Claude / Gemini.
    """
    return "Image description placeholder: diagram, screenshot, or chart from the document."

def extract_pdf_for_embeddings(pdf_path: str):
    doc = fitz.open(pdf_path)
    records = []

    for page_number, page in enumerate(doc, start=1):
        # 1. Extract text in reading order
        page_text = page.get_text("text", sort=True)

        # 2. Split text into semantic-ish chunks
        text_chunks = splitter.split_text(page_text)

        for i, chunk in enumerate(text_chunks):
            records.append({
                "content": chunk,
                "metadata": {
                    "source": pdf_path,
                    "page": page_number,
                    "chunk_type": "text",
                    "chunk_index": i
                }
            })

        # 3. Extract images from page
        image_list = page.get_images(full=True)

        for img_index, img in enumerate(image_list):
            xref = img[0]
            image_data = doc.extract_image(xref)
            image_bytes = image_data["image"]

            caption = caption_image(image_bytes)

            records.append({
                "content": caption,
                "metadata": {
                    "source": pdf_path,
                    "page": page_number,
                    "chunk_type": "image_caption",
                    "image_index": img_index
                }
            })

    return records

records = extract_pdf_for_embeddings(PDF_PATH)

for r in records[:3]:
    print(r)

from openai import OpenAI

client = OpenAI()

def create_embedding(text: str):
    response = client.embeddings.create(
        model="text-embedding-3-small",
        input=text
    )
    return response.data[0].embedding

for record in records:
    record["embedding"] = create_embedding(record["content"])
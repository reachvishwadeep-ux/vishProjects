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

#create chunks, embed and store in vector database in memory
#import ollama

import generator
import correctness_evaluator
import test_dataset
from langsmith import Client

client = Client()
# Create the dataset and examples in LangSmith
dataset_name = "vishtest-Lilian Weng Blogs Q&A"
if not client.has_dataset(dataset_name=dataset_name):
    dataset = client.create_dataset(dataset_name=dataset_name)
    client.create_examples(
        dataset_id=dataset.id,
        examples=test_dataset.examples
    )

def target(inputs: dict) -> dict:
    return generator.rag_bot(inputs["question"])

experiment_results = client.evaluate(
    target,
    data=dataset_name,
    evaluators=[correctness_evaluator.correctness],
    experiment_prefix="rag-doc-relevance",
    metadata={"version": "LCEL context, gpt-4-0125-preview"},
)

# Explore results locally as a dataframe if you have pandas installed
experiment_results.to_pandas()
# RAG Evaluation Sequence Diagram

```mermaid
%%{init: {
  "theme": "base",
  "themeVariables": {
    "fontFamily": "Trebuchet MS, Verdana, sans-serif",
    "fontSize": "18px",
    "actorBorder": "#0f172a",
    "actorBkg": "#f8fafc",
    "actorTextColor": "#0f172a",
    "noteBkgColor": "#fff7ed",
    "noteBorderColor": "#fb923c",
    "signalTextColor": "#0f172a",
    "signalColor": "#0f172a"
  },
  "themeCSS": "
    .messageLine0, .messageLine1, .messageLine2, .messageLine3, .messageLine4, .messageLine5, .messageLine6 {
      stroke-width: 3.5px !important;
    }
    .messageText {
      font-size: 18px !important;
      font-weight: 800 !important;
      fill: #0f172a !important;
    }
    .actor text {
      font-size: 19px !important;
      font-weight: 800 !important;
      fill: #0f172a !important;
    }
    .noteText {
      font-size: 17px !important;
      font-weight: 700 !important;
    }
    .loopText {
      font-size: 17px !important;
      font-weight: 800 !important;
    }
    .actor-line {
      stroke: #64748b !important;
      stroke-width: 2.5px !important;
    }
    .sequenceNumber {
      font-size: 16px !important;
      font-weight: 800 !important;
    }
  "
}}%%
sequenceDiagram
    autonumber
    participant Eval as evaluation.py
    participant LS as LangSmith Client
    participant Target as target(inputs)
    participant Gen as generator.rag_bot(question)
    participant Ret as retriever.retriever
    participant LLM as ChatOpenAI (answer model)
    participant Judge as correctness_evaluator.correctness
    participant Grader as Structured Grader LLM

    rect rgb(255, 241, 242)
        Note over Eval,LS: Orchestration
        Eval->>LS: evaluate(target, data=dataset_name, evaluators=[correctness], ...)
    end

    loop for each dataset example
        rect rgb(239, 246, 255)
            Note over LS,Target: Target execution
            LS->>Target: target(inputs)
            Target->>Gen: rag_bot(inputs["question"])
        end

        rect rgb(236, 253, 245)
            Note over Gen,Ret: Retrieval
            Gen->>Ret: invoke(question)
            Ret-->>Gen: top-k docs
        end

        rect rgb(254, 249, 195)
            Note over Gen,LLM: Answer generation
            Gen->>Gen: Build prompt with docs_text
            Gen->>LLM: invoke(system prompt + user question)
            LLM-->>Gen: answer text
            Gen-->>Target: {"answers:": answer, "documents": docs}
            Target-->>LS: outputs
        end

        rect rgb(245, 243, 255)
            Note over LS,Grader: Evaluation
            LS->>Judge: correctness(inputs, outputs, reference_outputs)
            Judge->>Grader: invoke(grading instructions + Q/GT/student answer)
            Grader-->>Judge: {"explanation": "...", "correct": true/false}
            Judge-->>LS: bool score
        end
    end

    rect rgb(255, 247, 237)
        Note over LS,Eval: Results
        LS-->>Eval: experiment_results
        Eval->>Eval: experiment_results.to_pandas()
    end
```

## How to export

1. Open this file in VS Code and press Ctrl+Shift+V for Markdown preview.
2. If your Mermaid extension supports it, right-click the rendered diagram and export to SVG/PNG.
3. If not, copy the Mermaid block into https://mermaid.live and export from there.

import json
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

client = OpenAI()

response = client.chat.completions.create(
    model="gpt-4.1-mini",
    messages=[{"role":"user","content":"list input args of \n"
    "client.chat.completions.create API from OpenAI which can affect model accuracy \n"
    "and performance. Return the crisp response in JSON format only."}]
    )

print(response.choices[0].message.content)

"""
A typical response would be something like this:

```json
{
  "model": "Specifies the model to use, affecting accuracy and capabilities.",
  "messages": "Defines the conversation context; quality and relevance impact accuracy.",
  "temperature": "Controls randomness; lower values yield more focused and accurate responses.",
  "top_p": "Controls nucleus sampling; balances diversity and relevance affecting performance.",
  "max_tokens": "Limits response length; too low may truncate useful info, affecting accuracy.",
  "frequency_penalty": "Reduces repetition; can improve coherence but might affect response variety.",
  "presence_penalty": "Encourages new topics; impacts creativity and relevance.",
  "stop": "Specifies stop sequences; affects where the model stops generating text."
}
```


"""



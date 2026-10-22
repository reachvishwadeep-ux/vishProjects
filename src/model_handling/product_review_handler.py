import json
import sys
from dotenv import load_dotenv
import openai

load_dotenv()

prompt_template = """ You are a product review analyzer.
Given the review below, extract the following fields
and return ONLY valid JSON — no explanation, no markdown:
 
- sentiment: "positive", "negative", or "neutral"
- rating_estimate: a number from 1 to 5
- key_issues: a list of strings (max 3 items)
- would_recommend: true or false
 
Review: {review_text}
"""

review_text_positive = """Absolutely love this laptop! 
Battery lasts all day and the keyboard feels great. 
Would buy again."""

review_text_negative = "Terrible experience. " \
"The screen flickered constantly, " \
"customer support was useless, " \
"and it died after 2 months. Never again."

review_text_neutral = "It’s okay I guess. Does the job but nothing special. " \
"The price feels a bit high for what you get."

llm = openai.OpenAI()
failures = 0
for review_text in [review_text_positive, review_text_negative, 
                    review_text_neutral]:
    prompt = prompt_template.format(review_text=review_text)
    response = llm.chat.completions.create(
        model="gpt-3.5-turbo",
        messages=[{"role":"user","content":prompt}])
    
    raw_response = response.choices[0].message.content
    print(raw_response)
    try:
        if not isinstance(raw_response, str) or not raw_response.strip():
            raise ValueError("model returned an empty completion")

        start = raw_response.find("{")
        end = raw_response.rfind("}")
        if start == -1 or end == -1 or start > end:
            raise ValueError("response did not contain a JSON object")

        json_response = raw_response[start:end + 1]

        #json_response = "some prefix text " + json_response + " some suffix text"
        #revoew peamble and postamble from the response
        
        #handle if response is Key:value format instead of JSON
        if ":" in json_response and "{" not in json_response:
            json_response = "{" + json_response + "}"

        #check datatype in the response
        """
        if (json_response["sentiment"] not in ["positive", "negative", 
                                               "neutral"] or
            not (1 <= json_response["rating_estimate"] <= 5) or
            not isinstance(json_response["key_issues"], list) or
            not isinstance(json_response["would_recommend"], bool)):
            raise ValueError("Invalid data format in response")
        
        """                                                                                                                                                            


        data = json.loads(json_response)
        print(data)
        #print(type(data))
        #print(json.dumps(data, indent=2))
    except json.JSONDecodeError as e:
        print("Error decoding JSON:", e)
        print("Raw payload:", raw_response)
        failures += 1
    except ValueError as e:
        print("Error processing review response:", e)
        print("Raw payload:", raw_response)
        failures += 1

if failures:
    print(f"{failures} review response(s) failed.")
    sys.exit(1)
    

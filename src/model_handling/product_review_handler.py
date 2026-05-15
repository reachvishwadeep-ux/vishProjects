import os
import json
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
for review_text in [review_text_positive, review_text_negative, 
                    review_text_neutral]:
    prompt = prompt_template.format(review_text=review_text)
    response = llm.chat.completions.create(
        model="gpt-3.5-turbo",
        messages=[{"role":"user","content":prompt}])
    
    json_response = response.choices[0].message.content
    print(json_response)
    try:
        #json_response = "some prefix text " + json_response + " some suffix text"
        #revoew peamble and postamble from the response
        json_response = json_response[
            json_response.find("{"):json_response.rfind("}")+1]
        
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
        #print(type(data))
        #print(json.dumps(data, indent=2))
    except json.JSONDecodeError as e:
        print("Error decoding JSON:", e)
    

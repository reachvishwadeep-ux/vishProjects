"""Prompt templates shared by several example scripts."""

COUNTRY_JSON_PROMPT = """ Return the response in JSON format only.
    Example:
    {{
        "Country": "USA",
        "Capital": "Washington, D.C."
        "President": "Donald Trump"
    }}

    Now tell me about this country: {country_name}
    """

PRODUCT_REVIEW_PROMPT = """ You are a product review analyzer.
Given the review below, extract the following fields
and return ONLY valid JSON — no explanation, no markdown:

- sentiment: "positive", "negative", or "neutral"
- rating_estimate: a number from 1 to 5
- key_issues: a list of strings (max 3 items)
- would_recommend: true or false

Review: {review_text}
"""

PRODUCT_REVIEW_FIELDS = (
    "sentiment",
    "rating_estimate",
    "key_issues",
    "would_recommend",
)

HOROSCOPE_WEB_SEARCH_PROMPT = (
    "What was Aquarious career Horoscope for tomorrow based on moon sign? "
    "give structured ouput as Date, Horoscope, and Source. "
    "show output in indented form for better readability."
)

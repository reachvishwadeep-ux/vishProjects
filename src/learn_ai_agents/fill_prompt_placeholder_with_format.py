prompt = """ Return the response in JSON format only.
    Example:
    {{
        "Country": "USA",
        "Capital": "Washington, D.C."
        "President": "Donald Trump"
    }}

    Now tell me about this country: {country_name}
    """

print(prompt.format(country_name="India"))

"""
x={"is_valid":True, "revision_count":3}
y = lambda x: "researcher" if (not x["is_valid"] and x["revision_count"]> 2) else "engineer"
print(y(x))
"""

#sum two numbers
z = lambda a,b: (a + b )
print(z(3,4))
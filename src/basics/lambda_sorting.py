similarities =  []

similarities.append((" Ram", 0.9))
similarities.append((" Shyam", 0.8))
similarities.append((" Hari", 0.95))    

similarities.sort(key=lambda x: x[1], reverse=False)
print(similarities)
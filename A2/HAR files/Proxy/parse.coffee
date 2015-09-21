fs = require('fs');

input = fs.readFileSync('www.nytimes.com.har','utf8');

data = JSON.parse(input);

fun1 = ->
	console.log(data.log.entries.length);

urlDomain = (url) ->
	if (url.indexOf("://") > -1)
		domain = url.split('/')[2];
	else
		domain = url.split('/')[0];
	domain = domain.split(':')[0];
	return domain;

different_domains={}

fun2 = -> 
	entries = data.log.entries
	for entry in entries
		domain_name=urlDomain(entry.request.url)
		if different_domains[domain_name]?
			different_domains[domain_name]["downloaded_objects"]++
			different_domains[domain_name]["size"]+=entry.response.content.size
		else
			different_domains[domain_name]={"downloaded_objects":1,"size":entry.response.content.size}

fun2()
console.log(different_domains)

different_type_objects = {}

fun3 = -> 
	entries = data.log.entries
	for entry in entries
		object_type=entry.response.content.mimeType
		if different_type_objects[object_type]?
			different_type_objects[object_type]++
		else
			different_type_objects[object_type]=1

fun3()
console.log(different_type_objects)

# referrer = {}

# fun4 = ->
# 	entries = data.log.entries
# 	i=0
# 	for entry in entries
# 		refer = entry.request.headers[5].value
# 		console.log(i)
# 		console.log(refer)
# 		i++
# 		if referrer[refer]?
# 			referrer[refer]++
# 		else
# 			referrer[refer]=1

# fun4()
# console.log(referrer)
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


class Tree
	url : null
	object : null
	children : null
	constructor: (@url,@object) ->
		@children = []

tree = new Tree(data.log.entries[0].request.url,data.log.entries[0])
tmp={}

fun4 = ->
	arr = data.log.entries
	for entry in arr
		if arr.indexOf(entry) is 0
			continue
		if entry.request.headers[5].name isnt "Referer"
			continue
		if tmp[entry.request.headers[5].value]?
			tmp[entry.request.headers[5].value].push entry
		else
			tmp[entry.request.headers[5].value]=[entry]
	makeTree(tree)

makeTree = (t) ->
	url = t.url
	if tmp[url]?
		for obj in tmp[url]
			tmp_tree=new Tree(obj.request.url,obj)
			t.children.push tmp_tree
			makeTree(tmp_tree)
		delete tmp[url]


fun4()
console.log tmp
console.log tree
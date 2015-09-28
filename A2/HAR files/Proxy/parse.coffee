fs = require('fs')
_ = require('lodash')
{spawn,exec} = require 'child_process'

input = fs.readFileSync('www.nytimes.com.har','utf8');

data = JSON.parse(input);

# To calculate total number of objects
fun1 = ->
  console.log(data.log.entries.length);

# Extract host name from url
urlDomain = (url) ->
  if (url.indexOf("://") > -1)
    domain = url.split('/')[2];
  else
    domain = url.split('/')[0];
  domain = domain.split(':')[0];
  return domain;

# Total number of onjects, total size of objects and content size downloaded from each domain
different_domains={}
fun2 = -> 
  entries = data.log.entries
  for entry in entries
    domain_name=entry.request.headers[0].value
    if !different_domains[domain_name]?
      different_domains[domain_name]={"downloaded_objects":0,"content_size":0,"object_size":0}
    different_domains[domain_name]["downloaded_objects"]++
    different_domains[domain_name]["content_size"]+=entry.response.content.size
    different_domains[domain_name]["object_size"]+=(entry.response.headersSize + entry.response.bodySize)
fun2()
console.log(different_domains)

# Different types of objects downloaded
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


# Onject tree in csv format - (node_id,url,parent_node_id)
class ObjectTree
  url : null
  object : null
  children : null
  constructor: (@url,@object) ->
    @children = []
object_tree = new ObjectTree(data.log.entries[0].request.url,data.log.entries[0])
tmp={}

makeTree = (t) ->
  url = t.url
  if tmp[url]?
    for obj in tmp[url]
      tmp_tree=new ObjectTree(obj.request.url,obj)
      t.children.push tmp_tree
      makeTree(tmp_tree)
    delete tmp[url]

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
  console.dir(tmp)
  makeTree(object_tree)
fun4()


printObjectTree = (t,nid,pid) ->
  pattern = "#{nid},#{t.url},#{pid}"
  console.log(pattern)
  id=_.clone(nid)
  for child in t.children
    nid++
    printObjectTree(child,nid,id)
printObjectTree(object_tree,1,-1)


async=require 'async'
# Total number of tcp connections to each domain and details of each connection
tcp_connections={}
fun5 = ->
  arr = data.log.entries[1..5]
  async.forEach(arr, (entry,cb)->
    domain_name=entry.request.headers[0].value
    ip=entry.serverIPAddress
    if(not tcp_connections[domain_name]?)
      tcp_connections[domain_name]={"number_tcp_connections":0,"connections":{}}
      filter = "ip.dst==#{ip} && http"
      cmd = spawn 'tshark' , ['-r','nytimes.pcap','-Y',filter,'-T','fields','-e','ip.src','-e','ip.dst','-e' ,'tcp.port','-e','_ws.col.Info','-e','frame.number']
      all_data=""
      cmd.stdout.on('data',(data)->
        all_data+=data.toString()
      )
      cmd.stdout.on('end', (data) ->
        lines=all_data.split('\n')
        lines.splice(lines.length-1)
        num=0
        for line in lines
          fields=line.split('\t')
          port=fields[2].split(',')[0]
          url=fields[3].split(' ')[1]
          if(not tcp_connections[domain_name]["connections"][port]?)
            tcp_connections[domain_name]["connections"][port]={"urls":[]}
            num++;
          tcp_connections[domain_name]["connections"][port]["urls"].push(url)
        tcp_connections[domain_name]["number_tcp_connections"]=num;
        cb(null,false)
      )
    else
      cb(null,false) 
  ,(err,res)->
    console.log(tcp_connections)
    printDownloadTree()
  );

fun5()
printDownloadTree = ->
  id=0
  for key of tcp_connections
    domain_name=key
    for k of tcp_connections[key]["connections"]
      urls=tcp_connections[key]["connections"][k]["urls"]
      for url in urls
        pattern="#{key},#{id},#{url}"
        console.log(pattern)
      id++

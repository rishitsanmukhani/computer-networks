fs = require('fs')
_ = require('lodash')
async = require 'async'
{spawn,exec} = require 'child_process'

input = fs.readFileSync('www.nytimes.com.har','utf8');

data = JSON.parse(input);

urlDomain = (url) ->
  if (url.indexOf("://") > -1)
    domain = url.split('/')[2];
  else
    domain = url.split('/')[0];
  domain = domain.split(':')[0];
  return domain;

class ObjectTree
  url : null
  object : null
  children : null
  constructor: (@url,@object) ->
    @children = []

makeTree = (tree,referer_tree) ->
  url = tree.url
  if(referer_tree[url]?)
    for obj in referer_tree[url]
      tmp_tree=new ObjectTree(obj.request.url,obj)
      tree.children.push(tmp_tree)
      makeTree(tmp_tree,referer_tree)
    delete referer_tree[url]

DFS = (tree,nid,pid) ->
  str = "#{nid},#{tree.url},#{pid}\n"
  fs.appendFileSync("object_tree.csv",str)
  id=_.clone(nid)
  for child in tree.children
    nid++
    DFS(child,nid,id)

fun4 = ->
  object_tree = new ObjectTree(data.log.entries[0].request.url,data.log.entries[0])
  referer_tree={}
  arr = data.log.entries[1..]
  for entry in arr
    if(entry.response.status==200 && entry.response.bodySize>0)
      idx=5
      if(entry.request.headers[idx].name isnt "Referer")
        for header in entry.request.headers
          if(header.name=="Referer")
            idx=entry.request.headers.indexOf(header)
        if(idx==5)
          continue
      if(not referer_tree[entry.request.headers[idx].value]?)
        referer_tree[entry.request.headers[idx].value]=[]
      referer_tree[entry.request.headers[idx].value].push(entry)
  makeTree(object_tree,referer_tree)
  fs.writeFileSync("object_tree.csv","")
  DFS(object_tree,1,-1)
# fun4()

printDownloadTree = (tcp_connections)->
  fs.writeFileSync("download_tree.csv","")
  for k of tcp_connections
    for key of tcp_connections[k]
      arr=tcp_connections[k][key]
      for a in arr
        str=k+","+key+","+a.request.url+"\n"
        fs.appendFileSync("download_tree.csv",str)

fun5 = ->
  tcp_connections={}
  url_object={}
  arr=[]
  entries = data.log.entries
  for entry in entries
    if(entry.response.status==200 && entry.response.bodySize>0)
      url_object[entry.request.url]=entry
      arr.push(entry)
  async.forEach(arr,(entry,cb)->
    domain_name=entry.request.headers[0].value
    if(not tcp_connections[domain_name]?)
      tcp_connections[domain_name]={}
      command="tshark -r nytimes.pcap -Y \"http && http.host contains #{domain_name}\" -T fields -e tcp.stream -e _ws.col.Info"
      cmd = exec(command)
      all_data=""
      cmd.stdout.on('data',(data) -> all_data+=data.toString())
      cmd.stdout.on('end', (data) ->
        lines=all_data.split('\n')
        lines.splice(lines.length-1)
        for line in lines
          id=line.split('\t')[0]
          query_string=line.split('\t')[1].split(' ')[1]
          url="http://#{domain_name}#{query_string}"
          if(not tcp_connections[domain_name][id]?)
            tcp_connections[domain_name][id]=[]
          if(url_object[url]?)
            tcp_connections[domain_name][id].push(url_object[url])
        cb(null,false)
      )
    else
      cb(null,false)
  ,(err,res)->
    printDownloadTree(tcp_connections)
  );
fun5()

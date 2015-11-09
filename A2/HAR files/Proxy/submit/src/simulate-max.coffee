fs = require('fs')
async = require('async');
_ = require('lodash');
data = JSON.parse(fs.readFileSync('json.txt','utf8'));
connections = {}

class TreeNode
  constructor: (@id,@url,@children=[]) ->
    @connection = null
    @wait = 0
    @parent = null
    @connect = 0
    @receive = 0
  addChild: (child)->
    @children.push(child)
  toString: (indent=0)->
    short = @url
    if(short.length > 40)
      short = short[0...22]+'...'+short[-15..]
    space = ''
    for i in [0...indent]
      space += ' '
    out = "#{space}(##{@id}: #{short}, #{@children.length} children)\n"
    for child in @children
      out += child.toString(indent+4)
    # out += "\n#{space}"
    out
  process: (start, cb)->
    if(connections[@connection]==null)
      connections[@connection]={
        start: start
        connect: @connect
        other: 0
        num: 0
      }
    connections[@connection].num++
    delta = start - (connections[@connection].start + connections[@connection].connect + connections[@connection].other)

    if(delta > 0)
      connections[@connection].other += delta;
      delta = 0
    if(delta + @wait > 0)
      connections[@connection].other += @wait + delta
    connections[@connection].other+= @receive

    endTime = connections[@connection].other+connections[@connection].connect
    # console.log(connections[@connection],endTime);
    if @children.length
      async.map(@children, (child,cb)=>
        child.process(endTime,cb)
      ,(err,times)->
        cb(null,_.max(times))
      )
    else
      cb(null,endTime);

srcFile = process.argv[2]
objTreeCsv = fs.readFileSync(srcFile,'utf8');
objTreeCsv= objTreeCsv.split('\n')
objTreeIndex={}
objRevIndex = {}
objTree = null
# objTreeIndex['1']=objTree
# console.log(objTreeCsv)
for line in objTreeCsv
  if(!line)
    continue;
  [id,url,parent]=line[1...-1].split('","')
  node = new TreeNode(id,url)
  # console.log node,parent
  # console.log objTreeIndex
  objTreeIndex[id]=node;
  objRevIndex[url]=node;
  if(id=='1')
    objTree=node
  if(parent != '-1')
    objTreeIndex[parent].addChild(node);
    node.parent=objTreeIndex[parent];
objTreeCsv = null
# console.log(objTreeIndex['1'])
console.log(objTree.toString())

doms = {}

conid = 0

urls = []

for dom,cons of data
  doms[dom]={goodput:0}
  for port,con of cons
    objs = con[1..]
    for obj in objs
      url= obj.request.url
      urls[url]=1
      if(!objRevIndex[url]?)
        console.log("Unknown object?")
        continue;
      objRevIndex[url].connection = conid
      objRevIndex[url].domain = dom
      objRevIndex[url].wait = obj.timings.wait
      objRevIndex[url].connect = obj.timings.connect + obj.timings.send + obj.timings.dns
      objRevIndex[url].size = obj.response.headersSize + obj.response.bodySize
    connections[conid]=null
  conid++;

goodputs = fs.readFileSync('goodput.csv','utf8').split('\n');
max_gp=0
for gp in goodputs
  gp=gp.trim()
  if(!gp)
    continue;
  [gp,dom]=gp.split(', ');
  gp=parseFloat(gp)
  if(!doms[dom])
    console.log("#{dom} not found in tcp con json");
    continue;
  if(gp> doms[dom].goodput)
    doms[dom].goodput=gp;
  if(gp>max_gp)
    max_gp=gp;

for dom,props of doms
  if(props.goodput==0)
    props.goodput= max_gp
console.log doms
for id,obj of objTreeIndex
  if(obj.connection==null)
    # console.log("unknown "+obj.url);
    obj.parent.children = _.filter(obj.parent.children, (c)-> (c!=obj))
    delete objTreeIndex[id]
for id,obj of objTreeIndex
  obj.receive = obj.size / doms[obj.domain].goodput
# console.log ("pcap:"+Object.keys(urls).length)
# console.log("tree:"+Object.keys(objTreeIndex).length);
# console.log("Checking:");
console.log("startsim:");
objTree.process(0,(err,time)->
  console.log("final",time)
);



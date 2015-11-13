_=require('lodash')
async=require('async')
net = require('net')
fs = require('fs')
URL = require('url')
crypto = require('crypto')
exec = require('child_process').exec

if !Buffer::indexOf
  Buffer::indexOf = (needle) ->
    if !(needle instanceof Buffer)
      needle = new Buffer(needle + '')
    length = @length
    needleLength = needle.length
    pos = 0
    index = undefined
    i = 0
    while i < length
      if needle[pos] == @[i]
        if pos + 1 == needleLength
          return index
        else if pos == 0
          index = i
        ++pos
      else if pos
        pos = 0
        i = index
      ++i
    -1

requestObject = (url,opt,cb)->
  if (typeof opt) == 'function'
    cb=opt
    opt=null
  if(!opt)
    opt={}
  opt=_.extend({
    referrer: null
    socket: null
    },opt);
  if(typeof url == 'string')
    url=URL.parse(url);
  if(!url.port)
    url.port=80;
  client = null
  filename = url.pathname.replace(/[^a-zA-Z0-9._-]+/g,'_').replace(/([^a-zA-Z0-9]+$)/g,'')
  if(filename=='')
    filename='_index'
  if(filename.indexOf('.')==-1)
    filename+='.html'
  filename = './'+url.hostname+'/'+crypto.createHash('md5').update(url.href).digest("hex")[0..7]+filename
  fs.access(filename,(err)->
    callbackDone = false
    if(!err)
      console.log("Using #{url.href} from cache");
      return cb(null,filename,true)
    sendRequest = () ->
      console.log("Sending request to #{url.host} for ",if url.path.length>40 then "#{url.path[0...17]}...#{url.path[-20..]}" else url.path)
      client.write("GET #{url.path} HTTP/1.1\r\n")
      client.write("Host: #{url.hostname}\r\n")
      if(opt.referrer)
        client.write("Referer: #{opt.referrer}\r\n")
      client.write("Accept-Encoding: gzip\r\n")
      client.write("\r\n")
      if(!callbackDone)
        callbackDone=true
        cb(null,filename,false)
    if(opt.socket)
      client=opt.socket
      sendRequest();
    else
      return cb("Must pass a valod socket!");
  )


receiveObject = (filename,url,client, body, cb)->
  buffer=""
  headers={}
  status=""
  headersDone=false
  bodyDone=false
  parsedBody=[]
  chunkLength=-1
  partialChunk=false
  callbackDone = false
  onData = (data)->
    # console.log("Receiving #{url.href[0...23]}...")
    process.stdout.write('.');
    if(headersDone)
      body=Buffer.concat([body,data]);
    else
      oldLength=buffer.length
      buffer+=data.toString('utf8');
      i=buffer.indexOf('\r\n\r\n')
      if(i!=-1)
        lines=buffer[0...i].split('\r\n');
        status=lines[0]
        lines=lines[1..]
        for h in lines
          [key,val]=h.split(': ');
          headers[key.toLowerCase()]=val
        headersDone=true
        body=data[i+4-oldLength..]
    if(headersDone)
      if(headers['content-length']?)
        expectedLength=parseInt(headers['content-length'])
        if(body.length >= expectedLength)
          parsedBody=[body[0...expectedLength]]
          body=body[expectedLength..]
          bodyDone=true
      else if(headers['transfer-encoding']=='chunked')
        parseChunk = ->
          if(chunkLength!=-1)
            if(body.length>=chunkLength)
              chunk=body[0...chunkLength]
              parsedBody.push(chunk)
              body=body[chunkLength..]
              console.log("chunk found: ",chunk.length,chunkLength);
              partialChunk=true
            if(partialChunk && body.indexOf('\r\n')==0)
              if(chunkLength==0) #final chunk
                bodyDone=true
              chunkLength=-1
              body=body[2..]
              partialChunk=false
          if(chunkLength==-1)
            i=body.indexOf('\r\n')
            if(i!=-1)
              chunkHeader=body[0...i]
              console.log("chunk header: ",chunkHeader.toString())
              chunkLength=parseInt(chunkHeader.toString(),16);
              body=body[i+2..]
              parseChunk()
        parseChunk()
      else
        console.log("Unsupported encoding or content-length not found.")
        console.log(headers)
        bodyDone=true

    if(bodyDone && !callbackDone)
      callbackDone=true;
      client.removeListener('data',onData);
      parsedBody=Buffer.concat(parsedBody)
      console.log status
      # console.log headers
      console.log parsedBody.length
      if(parsedBody.length>0)
        fs.mkdir('./'+url.hostname,(err)->
          if(headers['content-encoding']=='gzip')
            filename+='.gz'
          fs.writeFile(filename,parsedBody,(err)->
            shortname=if filename.length>50 then "#{filename[0...22]}...#{filename[-25..]}" else filename
            console.log("Written #{shortname}")
            cb(err,body)
            if(headers['content-encoding']=='gzip')
              console.log("Gunzipping #{shortname}..")
              exec("gunzip #{filename}",(error, stdout, stderr)->
                if(!error)
                  console.log("gunzipped.");
                else
                  console.log("gunzip failed: ",error);
              )

          );
        )
      else
        cb(null,body);
  client.on('data',onData);

MAX_CONNECTIONS = 20
MAX_CONNECTIONS_PER_SERVER = 5
MAX_OBJECTS_PER_CONNECTION = 1

class Connection
  constructor: (url,cb)->
    @queue = []
    @queued = []
    if (typeof url) == 'string'
      url=URL.parse(url)
    if(!url.port)
      url.port='80'
    url.port = parseInt(url.port)
    @domain = url.hostname
    @receiving = false
    @numQueued = 0
    @numActive = 0
    @onReceive = ()->null
    @onStopReceive = ()->null
    @processing = false
    @socket = new net.Socket();
    console.log("Connecting to "+@domain);
    @socket.connect(url.port,url.hostname,cb);
    @socket.on('error',(err)=>
      @socket.destroy();
      console.log("Connection error: ",err)
    )
  push: (url,referrer,cb)->
    if(typeof url) == 'string'
      url = URL.parse(url)
    if @domain == ""
      @domain = url.hostname
    if @domain != url.hostname
      return cb("Hostname must be same for a single connection")
    @numQueued++
    @queue.push({url:url,referrer:referrer,cb:cb})
    @process()
  checkLimit: ()->
    MAX_OBJECTS_PER_CONNECTION <= @numQueued
  receive: ()->
    body = new Buffer(0)
    @receiving=true;
    @onReceive();
    receiveOne = ()=>
      if(@queued.length==0)
        @receiving=false
        @onStopReceive()
        @process()
        return
      front=@queued[0]
      receiveObject(front.filename,front.url,@socket,body,(err,newbody)=>
        body=newbody
        @queued.shift();
        @numActive--;
        receiveOne()
        front.cb();
        # if(!@
      )
    receiveOne()
  process: ()->
    if(@processing) #dont start multiple instances
      return
    @processing = true
    while MAX_OBJECTS_PER_CONNECTION > @numActive
      if(@queue.length==0)
        @processing = false
        return;
      front=@queue.pop()
      @numActive++
      requestObject(front.url,{socket: @socket, referrer: front.referrer},(err,filename,cached)=>
        if(cached)
          front.cb()
          return;
        front.filename=filename
        @queued.push(front);
        if(!@receiving)
          @receive()
      )

connections = {}
freeConnections= ()->
  for domain,cons of connections
    for con in cons
      if con.socket
        con.socket.end()
class TreeNode
  constructor: (@id,@url,@referrer="",@children=[]) ->
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
  process: (cb)->
    url = URL.parse(@url)
    if(!connections[url.hostname]?)
      connections[url.hostname]=[]
    pool = connections[url.hostname]
    best = null
    # minLen = 100000
    for con in pool
      len = con.numActive #+ con.queued.length
      if minLen > len
        minLen=len
        best=con
    proceed = ()=>
      best.push(url,@referrer,()=>
        if @children.length
          async.map(@children, (child,cb)=>
            child.process(cb)
          ,(err)->
            cb(err)
          )
        else
          cb();
      )
    if !best || (best.checkLimit() && pool.length< MAX_CONNECTIONS_PER_SERVER)
      best = new Connection(url,proceed)
      # best.onStopReceive =
      pool.push(best)
      console.log("New Connection (#{pool.length} total) for #{url.hostname}")
    else
      proceed()

if process.argv.length < 3
  console.log('Usage: node download <object-tree-csv>');
  return process.exit(1);

try
  srcFile = process.argv[2]
  objTreeCsv = fs.readFileSync(srcFile,'utf8');
  objTreeCsv=objTreeCsv.split('\n')
  objTreeIndex={}
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
    if(id=='1')
      objTree=node
    if(parent != '-1')
      objTreeIndex[parent].addChild(node);
      node.referrer=objTreeIndex[parent].url;
  objTreeCsv = null
  # console.log(objTreeIndex['1'])
  console.log(objTree.toString())
  # console.log(child.toString() for child in objTree.children)
  targetDir='./dl_'+srcFile
  fs.mkdir(targetDir,(err)->
    process.chdir(targetDir);
    console.log("Working directory: "+targetDir);
    # for id,obj of objTreeIndex
    objTree.process((err)->
      console.log("Done All!");
      freeConnections()
    )
    # async.map(objTreeIndex, (obj,cb)->
    #   download(obj.url,(err,socket)->
    #     if(socket)
    #       socket.end();
    #     cb();
    #   );
    # ,(err)->
    #   console.log("done all!")
    # );

    # download('http://theappbin.com/asd.txt',(err,socket)->
    #   if(socket)
    #     socket.end();
    #   console.log('Done All!');
    # );
  )
catch e
  console.log("Caught exception: ",e);
  return process.exit(1);
_=require('lodash')
async=require('async')
net = require('net')
fs = require('fs')
URL = require('url')
crypto = require('crypto')

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

download= (url,opt,cb)->
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
    callbackDone=false
    if(!err)
      console.log("Using #{url.href} from cache");
      return cb()
    sendRequest = () ->
      console.log("Sending request to #{url.host} for #{url.path}")
      client.write("GET #{url.path} HTTP/1.1\r\n")
      client.write("Host: #{url.hostname}\r\n")
      client.write("Accept-Encoding: gzip\r\n")
      client.write("\r\n")
      buffer=""
      headers={}
      status=""
      headersDone=false
      bodyDone=false
      body=new Buffer(0)
      parsedBody=[]
      chunkLength=-1
      partialChunk=false

      client.on('data',(data)->
        console.log(".")
        if(bodyDone)
          console.log "excess data!"
          return;
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
          parsedBody=Buffer.concat(parsedBody)
          console.log status
          console.log headers
          console.log parsedBody.length
          fs.mkdir('./'+url.hostname,(err)->
            fs.writeFile(filename,parsedBody,(err)->
              console.log("Written #{filename}");
              callbackDone=true
              cb(err,client)
            );
          )
      )
    if(opt.socket)
      client=opt.socket
      sendRequest();
    else
      client = new net.Socket();
      console.log("Connecting to "+url.hostname);
      client.connect(url.port,url.hostname,sendRequest);
      client.on('error',(err)->
        bodyDone=true
        console.log("Connection error:",err)
        console.log("while processing: "+url.href);
        if(!callbackDone)
          callbackDone=true
          cb(err);
      )
  )


MAX_CONNECTIONS = 20
MAX_CONNECTIONS_PER_SERVER = 10
MAX_OBJECTS_PER_CONNECTION = 5

class Connection
  constructor: ()->
    @domain = ""
    @queue = []
    @queued = []
    @socket = null
  req: (url,cb)->
    url = URL.parse(url)
    if @domain == ""
      @domain = url.hostname
    if @domain != url.hostname
      return cb("Hostname must be same for a single connection")
    queue.push({url:url,cb:cb})
  process: ()->
    while MAX_CONNECTIONS_PER_SERVER > queued.length
      job=queue.pop()
      queued.push(job)

class TreeNode
  constructor: (@id,@url,@children=[]) ->
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
  objTreeCsv = null
  # console.log(objTreeIndex['1'])
  console.log(objTree.toString())
  # console.log(child.toString() for child in objTree.children)
  targetDir='./dl_'+srcFile
  fs.mkdir(targetDir,(err)->
    process.chdir(targetDir);
    console.log("Working directory: "+targetDir);
    # for id,obj of objTreeIndex
    async.map(objTreeIndex, (obj,cb)->
      download(obj.url,(err,socket)->
        if(socket)
          socket.end();
        cb();
      );
    ,(err)->
      console.log("done all!")
    );

    # download('http://theappbin.com/asd.txt',(err,socket)->
    #   if(socket)
    #     socket.end();
    #   console.log('Done All!');
    # );
  )
catch e
  console.log("Caught exception: ",e);
  return process.exit(1);
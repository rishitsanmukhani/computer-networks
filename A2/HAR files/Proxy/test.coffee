net = require('net')
client= new net.Socket()
url=require('url').parse('http://sarthy.in/2D19E84F3FB494FA4B9A53EF94398C8C.txt')
#http://cse.iitd.ac.in/~cs1130258/')
client.connect(80,url.hostname,()->
  client.write("GET #{url.path} HTTP/1.1\r\n")
  client.write("Host: #{url.hostname}\r\n")
  # client.write("Connection: keep-alive\r\n")

  client.write("\r\n")
)
i=0;
all = ""
headDone=false
client.on('data',(data)->
  all += data.toString()
  i = all.indexOf('\r\n\r\n')
  if(i!=-1 && !headDone)
    headDone=true
    console.log(all[0...i])
  console.log("---");
  if(i>5)
    return;
  i++;
  # client.write("GET #{url.path} HTTP/1.1\r\n")
  # client.write("Host: #{url.hostname}\r\n")
  # client.write("\r\n")
)
client.on('error',(err)->
  console.log err
)
client.on('close',(a,b)->
  console.log(a,b)
)
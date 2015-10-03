net = require('net')
fs = require('fs')
input = fs.readFileSync('www.nytimes.com.har','utf8');
data = JSON.parse(input);

client = new net.Socket();

fun = ->
  entries=data.log.entries[0..0]
  for entry in entries
    req=entry.request.method+" "
    req+=entry.request.url+" "
    req+=entry.request.httpVersion+"\n\n"
    console.log(req)
    client.connect(80,entry.request.headers[0].value,()->
      console.log("Connected successfully")
      client.write(req,'utf8')
    )
    # client.on('data',(data)->
    #   console.log("Received:")
    #   console.log(data)
    # )
    # client.on('close', () ->
    #   console.log('Connection closed');
    # );
client.connect(80,'www.iitd.ac.in',() ->
  console.log("Connected successfully")
  client.write("GET / HTTP/1.1\r\n",'utf8')
  client.write("Host: www.iitd.ac.in\r\n",'utf8')
  client.write("Accept-Encoding: gzip\r\n")
  client.write("\r\n")
  all_data=""
  client.on('data',(data)->
    console.log("Received:")
    all_data += data.toString()
  )
  client.on('')
  client.end()
)
# fun()
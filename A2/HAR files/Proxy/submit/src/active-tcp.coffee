fs = require('fs')
_ = require('lodash')
async = require('async')
{spawn,exec} = require 'child_process'

input = fs.readFileSync('www.nytimes.com.har','utf8');

data = JSON.parse(input);

tcp_connections={}
fun2 = ->
  url_object={}
  entries = data.log.entries
  for entry in entries
    url_object[entry.request.url]=entry
  arr = data.log.entries
  async.forEach(arr,(entry,cb)->
    domain_name=entry.request.headers[0].value
    if(not tcp_connections[domain_name]?)
      tcp_connections[domain_name]={}
      command="tshark -r nytimes.pcap -Y \"http && http.host contains #{domain_name}\" -T fields -e tcp.port -e frame.time_relative -e _ws.col.Info"
      cmd = exec(command)
      all_data=""
      cmd.stdout.on('data',(data) -> all_data+=data.toString())
      cmd.stdout.on('end', (data) ->
        lines=all_data.split('\n')
        lines.splice(lines.length-1)
        for line in lines
          port=line.split('\t')[0].split(',')[0]
          time=line.split('\t')[1]
          query_string=line.split('\t')[2].split(' ')[1]
          url="http://#{domain_name}#{query_string}"
          if(not tcp_connections[domain_name][port]?)
            tcp_connections[domain_name][port]=[0]
          tcp_connections[domain_name][port][0]=time
          if(url_object[url]?)
            tcp_connections[domain_name][port].push(url_object[url])
        cb(null,false)
      )
    else
      cb(null,false)
  ,(err,res)->
    fs.writeFileSync("active-tcp.txt","",'utf8')
    #console.log tcp_connections
    diff = 0
    start_time = 0
    end_time = 0
    for k of tcp_connections
      for key of tcp_connections[k]
        arr=tcp_connections[k][key][1..]
        i=0
        for a in arr
          i++
          start_time=(new Date(a.startedDateTime)).getTime()
          end_time=start_time+a.time
          difference = end_time - start_time
          if difference > diff
            diff = difference
            start_time = start_time
            end_time = end_time
    maxActiveConnection = 0
    for m of tcp_connections
      for key1 of tcp_connections[m]
        arr2=tcp_connections[m][key1][1..]
        j=0
        for b in arr2
          j++
          start_time1=(new Date(b.startedDateTime)).getTime()
          end_time1=start_time1+b.time
          if start_time1 < end_time and end_time1 > start_time
            maxActiveConnection = maxActiveConnection + 1
    fs.appendFileSync("active-tcp.txt","\nMaximum number of TCP connections across domain that is simultaneously active is "+(maxActiveConnection)+"\n",'utf8')
          
);

fun2()

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
    fs.writeFileSync("max_tcp_per_domain.txt","",'utf8')
    #console.log tcp_connections
    for k of tcp_connections
      #fs.appendFileSync("max_tcp_per_domain.txt","\nDomain Name: "+k+"\n",'utf8')
      endArr = []
      maxTcp = 0
      for key of tcp_connections[k]
        #fs.appendFileSync("max_tcp_per_domain.txt","\nNew connections:\nPORT = "+key+"\n",'utf8')
        arr=tcp_connections[k][key][1..]
        i=0
        for a in arr
          i++
          #fs.appendFileSync("max_tcp_per_domain.txt",i+" -> "+a.request.url+'\n','utf8')
          start_time=(new Date(a.startedDateTime)).getTime()
          end_time=start_time+a.time
          #str="\nTiming\n";
          #str+=("\nStartTime: "+start_time)
          #str+=("\nEndTime:"+end_time+"\n")
          endArr.push(end_time)
          if i >= 2
          	if start_time < endArr[i-1]
          		maxTcp = maxTcp + 1    
          #fs.appendFileSync("max_tcp_per_domain.txt",str+'\n','utf8')
      if maxTcp is 0
      	maxTcp = 1
      fs.appendFileSync("max_tcp_per_domain.txt","\nMaximum number of TCP connections opened for "+k+" is "+(maxTcp)+"\n",'utf8')

);

fun2()

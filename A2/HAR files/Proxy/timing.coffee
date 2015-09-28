fs = require('fs')
_ = require('lodash')
async = require('async')
{spawn,exec} = require 'child_process'

input = fs.readFileSync('www.nytimes.com.har','utf8');

data = JSON.parse(input);

download_time=0
fun = ->
  entries = data.log.entries
  end_time = 0;
  for entry in entries
    start_time=(new Date(entry.startedDateTime)).getTime()
    if(start_time+entry.time > end_time)
      end_time=start_time+entry.time
  download_time=(end_time-(new Date(entries[0].startedDateTime)).getTime())
fun()
console.log("Download time : "+download_time)

domains_dns_time={}
fun1 = ->
  entries = data.log.entries
  uniq_domains=_.uniq(_.map(entries,(n)->n.request.headers[0].value))
  async.forEach(uniq_domains,(domain,cb)->
    domains_dns_time[domain]=[]
    str="tshark -r nytimes.pcap -Y \"dns && ip.src==192.168.0.2\" -T fields -e dns.id -e _ws.col.Info | grep #{domain}"
    cmd = exec(str)
    all_data=""
    cmd.stdout.on('data',(data)->
      all_data+=data.toString()
    )
    cmd.stdout.on('end', (data) ->
      arr=all_data.split('\n')
      arr.splice(arr.length-1)
      ids=_.map(arr,(n) -> n.split('\t')[0])
      for id in ids
        domains_dns_time[domain].push({"#{id}":0})
      cb(null,false)
    )
  ,(err,res)->
    id_dns_time={}
    str="tshark -r nytimes.pcap -Y \"dns && ip.dst==192.168.0.2\" -T fields -e dns.id -e dns.time -e dns.cname"
    cmd = exec(str)
    all_data=""
    cmd.stdout.on('data',(data)->
      all_data+=data.toString()
    )
    cmd.stdout.on('end', (data) ->
      arr=all_data.split('\n')
      arr.splice(arr.length-1)
      _.map(arr,(n) ->
          ar=n.split('\t')
          id_dns_time[ar[0]]=ar[1]
        )
      for key,value of domains_dns_time
        for obj in value
          for key of obj
            obj[key]=id_dns_time[key]
      console.log(domains_dns_time)
    )
  );

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
    fs.writeFileSync("tcp_connection.txt","",'utf8')
    for k of tcp_connections
      fs.appendFileSync("tcp_connection.txt","Domain Name: "+k+"\n\n",'utf8')
      for key of tcp_connections[k]
        fs.appendFileSync("tcp_connection.txt","New connections:\nPORT = "+key+"\n",'utf8')
        active_time=tcp_connections[k][key][0]
        fs.appendFileSync("tcp_connection.txt","Active Time = "+active_time+"\n",'utf8')
        arr=tcp_connections[k][key][1..]
        total_time=0
        total_data=0
        total_receive_time=0
        maxi_goodput=0
        i=0
        for a in arr
          i++
          fs.appendFileSync("tcp_connection.txt",i+" -> "+a.request.url+'\n','utf8')
          str="Timing";
          str+=("\nConnect: "+a.timings.connect)
          str+=("\nWaiting: "+a.timings.wait)
          str+=("\nReceive: "+a.timings.receive)
          str+=("\nSend: "+a.timings.send)
          if(a.timings.receive>0)
            goodput=(a.response.headersSize+a.response.bodySize)/a.timings.receive
            str+=("\nGoodput: "+goodput)
            if(goodput>maxi_goodput)
              maxi_goodput=goodput
          total_time += (a.timings.send + a.timings.wait+a.timings.receive)
          total_data += (a.response.headersSize + a.response.bodySize)
          total_receive_time += a.timings.receive
          fs.appendFileSync("tcp_connection.txt",str+'\n','utf8')

        active_percentage=(total_time)/(1000*active_time)
        str="Active Percentage : "+100*active_percentage+"\n"
        str+="Idle Percentage : "+100*(1-active_percentage)+"\n"
        if(total_receive_time>0)
          str+="Average goodput : "+(total_data/total_receive_time)+"\n"
          str+="Maximum goodput : "+maxi_goodput+"\n"
        fs.appendFileSync("tcp_connection.txt",str+"\n\n",'utf8')

  );

fun2()

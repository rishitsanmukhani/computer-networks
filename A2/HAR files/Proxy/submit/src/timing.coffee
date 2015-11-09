fs = require('fs')
_ = require('lodash')
async = require('async')
{spawn,exec} = require 'child_process'

if(process.argv.length < 4)
  console.log('Usage: node download <har-file> <pcap-file>');
  return process.exit(1);
har=process.argv[2]
pcap=process.argv[3]
srcip="192.168.0.2"
if(har=="www.vox.com.har")
  srcip="192.168.0.4"

input = fs.readFileSync(har,'utf8')
data = JSON.parse(input);
fs.writeFileSync("data.csv","",'utf8')

funDownloadTime = ->
  download_time=0
  entries = data.log.entries
  end_time = 0;
  for entry in entries
    start_time=(new Date(entry.startedDateTime)).getTime()
    if(start_time+entry.time > end_time)
      end_time=start_time+entry.time
  download_time=(end_time-(new Date(entries[0].startedDateTime)).getTime())
  console.log("Download time: "+download_time)
funDownloadTime()

funDNSTime = ->
  domains_dns_time={}
  entries = data.log.entries
  uniq_domains=_.uniq(_.map(entries,(n)->n.request.headers[0].value))
  async.forEach(uniq_domains,(domain,cb)->
    domains_dns_time[domain]=[]
    str="tshark -r #{pcap} -Y \"dns && ip.src==#{srcip}\" -T fields -e dns.id -e _ws.col.Info | grep #{domain}"
    cmd = exec(str)
    all_data=""
    cmd.stdout.on('data',(data)->
      all_data+=data.toString()
    )
    cmd.stdout.on('end', (data) ->
      arr=all_data.split('\n')
      arr.splice(arr.length-1)
      ids=_.uniq(_.map(arr,(n) -> n.split('\t')[0]))
      for id in ids
        domains_dns_time[domain].push({"#{id}":0})
      cb(null,false)
    )
  ,(err,res)->
    id_dns_time={}
    str="tshark -r #{pcap} -Y \"dns && ip.dst==#{srcip}\" -T fields -e dns.id -e dns.time -e dns.cname"
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
      fs.writeFileSync("dns.txt","")
      for k,value of domains_dns_time
        str=("\nDomain Name: "+k+"\n")
        if(value.length==0)
          str+=("DNS Query not launched\n")
        else
          for obj in value
            for key of obj
              obj[key]=id_dns_time[key]
              str+=("Time spent for DNS Query "+key+": "+id_dns_time[key]+"\n")
        fs.appendFileSync("dns.txt",str)
    )
  );
funDNSTime()

tcp_connections={}
fun = ->
  url_object={}
  entries = data.log.entries
  objs=0
  arr=[]
  for entry in entries
    if(entry.response.status==200 && entry.response.bodySize>0)
      url_object[entry.request.url]=entry
      objs++;
      arr.push(entry)
  async.forEach(arr,(entry,cb)->
    domain_name=entry.request.headers[0].value
    if(not tcp_connections[domain_name]?)
      tcp_connections[domain_name]={}
      command="tshark -r #{pcap} -Y \"http && http.host contains #{domain_name}\" -T fields -e tcp.port -e frame.time_relative -e _ws.col.Info"
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
    funTCP(tcp_connections,url_object)
    funQue3a(tcp_connections)
    funBrowser(tcp_connections)
  );
fun()

funQue3a = (tcp_connections)->
  entries = data.log.entries
  types_of_objects={}
  for entry in entries
    if(entry.response.status==200 && entry.response.bodySize>0)
      object_type=entry.response.content.mimeType
      if(not types_of_objects[object_type]?)
        types_of_objects[object_type]=0
      types_of_objects[object_type]++ 
  fs.writeFileSync("3a.txt","",'utf8')
  str="Different types of objects:\n"
  total=0
  nObjects=0
  _str=""
  for key of types_of_objects
    str+=(key+" - "+types_of_objects[key]+"\n")
    _str+=(key+","+types_of_objects[key]+"\n")
    total+=types_of_objects[key]
  str+=("Total - "+total+"\n\n")
  fs.appendFileSync("3a.txt",str)
  fs.writeFileSync("object_types.csv",_str,'utf8')
  _str1=_str2=_str3=_str4=""
  for k of tcp_connections
    str=("Domain Name: "+k+"\n")
    num_of_connection=0
    num_of_objects=0
    total_content_size=0
    total_object_size=0
    for key of tcp_connections[k]
      csize=0
      osize=0
      str+=("PORT: "+key+"\t")
      arr=tcp_connections[k][key][1..]
      for a in arr
        csize+=a.response.content.size
        osize+=a.response.headersSize+a.response.bodySize
      str+=("Objects: "+arr.length+"\t")
      str+=("Content-size: "+csize+"\t")
      str+=("Object-size: "+osize+"\t\n")
      num_of_connection++
      num_of_objects+=arr.length
      total_content_size+=csize
      total_object_size+=osize
    nObjects+=num_of_objects
    str+=("Connections: "+num_of_connection+"\n")
    _str1+=num_of_connection+"\n"
    str+=("Total Objects: "+num_of_objects+"\n")
    _str2+=num_of_objects+"\n"
    str+=("Total Content-size: "+total_content_size+"\n")
    str+=("Total Object-size: "+total_object_size+"\n\n")
    _str3+=total_object_size+"\n"
    fs.appendFileSync("3a.txt",str)
  str=("\nTotal Objects Downloaded: "+nObjects+"\n")
  fs.appendFileSync("3a.txt",str)
  fs.appendFileSync("data.csv",_str1+"\n\n")
  fs.appendFileSync("data.csv",_str2+"\n\n")
  fs.appendFileSync("data.csv",_str3+"\n\n")

funTCP = (tcp_connections,url_object)->
  fs.writeFileSync("3c.txt","",'utf8')
  total_data_network=0
  total_receive_time_network=0
  maximum_goodput_network=0
  _str1=_str2=""
  _str3=""
  for k of tcp_connections
    fs.appendFileSync("3c.txt","Domain Name: "+k+"\n\n",'utf8')
    for key of tcp_connections[k]
      fs.appendFileSync("3c.txt","New connections:\nPORT = "+key+"\n",'utf8')
      active_time=tcp_connections[k][key][0]
      fs.appendFileSync("3c.txt","Active Time = "+active_time+"\n",'utf8')
      arr=tcp_connections[k][key][1..]
      total_time=0
      total_data=0
      total_receive_time=0
      max_object_size=0
      receive_time=0
      i=0
      for a in arr
        i++
        fs.appendFileSync("3c.txt",i+" -> "+a.request.url+'\n','utf8')
        str="Timing";
        str+=("\nConnect: "+a.timings.connect)
        str+=("\nWaiting: "+a.timings.wait)
        str+=("\nReceive: "+a.timings.receive)
        str+=("\nSend: "+a.timings.send)
        if(a.timings.receive>0 and (a.response.headersSize + a.response.bodySize)>max_object_size)
          max_object_size=a.response.headersSize+a.response.bodySize
          receive_time=a.timings.receive
        total_time += (a.timings.send + a.timings.wait+a.timings.receive)
        total_data += (a.response.headersSize + a.response.bodySize)
        total_receive_time += a.timings.receive
        fs.appendFileSync("3c.txt",str+'\n','utf8')

      total_data_network+=total_data
      total_receive_time_network+=total_receive_time
      active_percentage=(total_time)/(1000*active_time)
      if(active_percentage>=1)
        active_percentage=1
      str="Active Percentage : "+100*active_percentage+"\n"
      str+="Idle Percentage : "+100*(1-active_percentage)+"\n"
      if(total_receive_time>0)
        str+="Average goodput : "+(total_data/total_receive_time)+"\n"
        _str1+=total_data/total_receive_time+"\n"
        str+="Maximum goodput : "+max_object_size/receive_time+"\n"
        _str3+=max_object_size/receive_time+", "+k+"\n"
        _str2+=max_object_size/receive_time+"\n"
        if(max_object_size/receive_time>maximum_goodput_network)
          maximum_goodput_network=max_object_size/receive_time
      fs.appendFileSync("3c.txt",str+"\n\n",'utf8')
  str="\n"
  str+="Average goodput(Network) : "+(total_data_network/total_receive_time_network)+"\n"
  str+="Maximum goodput(Network) : "+maximum_goodput_network+"\n"
  fs.appendFileSync("3c.txt",str+"\n\n",'utf8')
  fs.appendFileSync("data.csv",_str1+"\n\n")
  fs.appendFileSync("data.csv",_str2+"\n\n")
  fs.writeFileSync("goodput.csv",_str3)

getEndTimes = (arr)->
  start=-1
  end=-1
  for a in arr[1..]
    st=(new Date(a.startedDateTime)).getTime()
    if(st<start or start==-1)
      start=st
    if(st+a.time>end)
      end=st+a.time
  return [start,end]

tcpConnectionSame= (obj,start,end)->
  ans=0
  for key of obj
    if((obj[key]["start"]<=start && obj[key]["end"]>=start) or (obj[key]["start"]<=end && obj[key]["end"]>=end))
      ans++
  return ans

tcpConnectionAll= (time_schedule,start,end)->
  ans=0
  for k of time_schedule
    obj=time_schedule[k]
    for key of obj
      if((obj[key]["start"]<=start && obj[key]["end"]>=start) or (obj[key]["start"]<=end && obj[key]["end"]>=end))
        ans++
  return ans

funBrowser = (tcp_connections)->
  time_schedule={}
  for k of tcp_connections
    time_schedule[k]={}
    for key of tcp_connections[k]
      [start,end]=getEndTimes(tcp_connections[k][key])
      if(start!=-1)
        time_schedule[k][key]={start,end}
  fs.writeFileSync("browser_schedule.txt","",'utf8')
  _str1=""
  _str2=""
  for k of time_schedule
    str="Domain:" + k + "\n";
    num_same=0
    num_all=0
    for key of time_schedule[k]
      start=time_schedule[k][key]["start"]
      end=time_schedule[k][key]["end"]
      time_schedule[k][key]["nTCP_same"]=tcpConnectionSame(time_schedule[k],start,end)
      time_schedule[k][key]["nTCP_all"]=tcpConnectionAll(time_schedule,start,end)
      _str1+=time_schedule[k][key]["nTCP_same"]+"\n"
      _str2+=time_schedule[k][key]["nTCP_all"]+"\n"
      if(num_same<time_schedule[k][key]["nTCP_same"])
        num_same=time_schedule[k][key]["nTCP_same"]
      if(num_all<time_schedule[k][key]["nTCP_all"])
        num_all=time_schedule[k][key]["nTCP_all"]
    str+="MaxTCP among same domain: "+num_same+"\n";
    str+="MaxTCP across domains: "+num_all+"\n\n";
    fs.appendFileSync("browser_schedule.txt",str)
  fs.appendFileSync("data.csv",_str1+"\n\n")
  fs.appendFileSync("data.csv",_str2+"\n\n")


  
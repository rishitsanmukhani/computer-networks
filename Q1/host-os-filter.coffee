fs = require('fs');

input = fs.readFileSync('os.txt','utf8');

regex={}
regex.ip=/Nmap scan report for (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})([\S\s]+?)\n\n/gi

i=0;

while host = regex.ip.exec(input)
  # if(i>2)
  #   break
  i++
  ip=host[1];
  ports=[]
  os="unknown"
  regex.ports=/([\d]+)\/tcp[\s]+open[\s]+(.+)/gi
  while port = regex.ports.exec(host[2])
    ports.push(port[1]+"/"+port[2])

  if osres=/Running[^:]*: ([^(\n]*)(\(.+\))?/.exec(host[2])
    os=osres[1]
  # console.log(ip,ports,os);
  console.log("#{ip}, \"#{os}\", \"#{ports}\"");
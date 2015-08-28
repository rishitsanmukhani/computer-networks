request = require('request');
fs = require('fs');

cache={};
String.prototype.insertAt=(index, string)->
  this.substr(0, index) + string + this.substr(index)
getISP = (ip,cb)->
  if cache[ip]
    return cb(null,cache[ip])
  request('http://ipinfo.io/'+ip, (err,resp,body)->
    if (!err)
      cache[ip]=JSON.parse(body)
      cb(null,cache[ip]);
    else
      cb(err);
  )
input = fs.readFileSync('isptracert.txt','utf8');
output= input;
delta=0;
regex=/[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}/gi

while ipres=regex.exec(input)
  ip=ipres[0];
  index=ipres.index;
  getISP(ip,do (index)->
    (err,data)->
      # console.log(data);
      insertion="#{data.org ? 'unknown'}-";
      output=output.insertAt(index+delta,insertion);
      delta += insertion.length;
      fs.writeFileSync('ispoutput.txt',output);
  );
  # console.log(ip,index);
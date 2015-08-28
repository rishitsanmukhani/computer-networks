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
inputs = fs.readFileSync('isptracert.txt','utf8');
outputs= inputs;
regex=/[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}/gi
inputs = inputs.split("\n");
line=0;
for input in inputs
  while ipres=regex.exec(input)
    ip=ipres[0];
    index=ipres.index;
    getISP(ip,do (index,line)->
      (err,data)->
        # console.log(data);
        insertion=" - #{data.org ? 'unknown'}";
        outputs[line]+= insertion
        fs.writeFileSync('output.txt',outputs.join("\n"));
    );
    # console.log(ip,index);
  line++;
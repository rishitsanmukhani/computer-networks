fs = require('fs')
_ = require('lodash')
async = require('async')
URL = require('url')
{spawn,exec} = require 'child_process'

input = fs.readFileSync('www.nytimes.com.har','utf8');
data = JSON.parse(input);

fun = ->
  arr=data.log.entries
  url=[]
  for a in arr
    url.push(URL.parse(a.request.url))
  console.log(_.map(url,(a)->a.pathname))

fun()
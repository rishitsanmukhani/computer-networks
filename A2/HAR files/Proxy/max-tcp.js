// Generated by CoffeeScript 1.10.0
(function() {
  var _, async, data, exec, fs, fun2, input, ref, spawn, tcp_connections;

  fs = require('fs');

  _ = require('lodash');

  async = require('async');

  ref = require('child_process'), spawn = ref.spawn, exec = ref.exec;

  input = fs.readFileSync('www.nytimes.com.har', 'utf8');

  data = JSON.parse(input);

  tcp_connections = {};

  fun2 = function() {
    var arr, entries, entry, j, len, url_object;
    url_object = {};
    entries = data.log.entries;
    for (j = 0, len = entries.length; j < len; j++) {
      entry = entries[j];
      url_object[entry.request.url] = entry;
    }
    arr = data.log.entries;
    return async.forEach(arr, function(entry, cb) {
      var all_data, cmd, command, domain_name;
      domain_name = entry.request.headers[0].value;
      if (tcp_connections[domain_name] == null) {
        tcp_connections[domain_name] = {};
        command = "tshark -r nytimes.pcap -Y \"http && http.host contains " + domain_name + "\" -T fields -e tcp.port -e frame.time_relative -e _ws.col.Info";
        cmd = exec(command);
        all_data = "";
        cmd.stdout.on('data', function(data) {
          return all_data += data.toString();
        });
        return cmd.stdout.on('end', function(data) {
          var l, len1, line, lines, port, query_string, time, url;
          lines = all_data.split('\n');
          lines.splice(lines.length - 1);
          for (l = 0, len1 = lines.length; l < len1; l++) {
            line = lines[l];
            port = line.split('\t')[0].split(',')[0];
            time = line.split('\t')[1];
            query_string = line.split('\t')[2].split(' ')[1];
            url = "http://" + domain_name + query_string;
            if (tcp_connections[domain_name][port] == null) {
              tcp_connections[domain_name][port] = [0];
            }
            tcp_connections[domain_name][port][0] = time;
            if ((url_object[url] != null)) {
              tcp_connections[domain_name][port].push(url_object[url]);
            }
          }
          return cb(null, false);
        });
      } else {
        return cb(null, false);
      }
    }, function(err, res) {
      var a, endArr, end_time, i, k, key, l, len1, maxTcp, results, start_time;
      fs.writeFileSync("max_tcp_per_domain.txt", "", 'utf8');
      results = [];
      for (k in tcp_connections) {
        endArr = [];
        maxTcp = 0;
        for (key in tcp_connections[k]) {
          arr = tcp_connections[k][key].slice(1);
          i = 0;
          for (l = 0, len1 = arr.length; l < len1; l++) {
            a = arr[l];
            i++;
            start_time = (new Date(a.startedDateTime)).getTime();
            end_time = start_time + a.time;
            endArr.push(end_time);
            if (i >= 2) {
              if (start_time < endArr[i - 1]) {
                maxTcp = maxTcp + 1;
              }
            }
          }
        }
        if (maxTcp === 0) {
          maxTcp = 1;
        }
        results.push(fs.appendFileSync("max_tcp_per_domain.txt", "\nMaximum number of TCP connections opened for " + k + " is " + maxTcp + "\n", 'utf8'));
      }
      return results;
    });
  };

  fun2();

}).call(this);
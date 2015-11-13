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
    var arr, entries, entry, l, len, url_object;
    url_object = {};
    entries = data.log.entries;
    for (l = 0, len = entries.length; l < len; l++) {
      entry = entries[l];
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
          var len1, line, lines, n, port, query_string, time, url;
          lines = all_data.split('\n');
          lines.splice(lines.length - 1);
          for (n = 0, len1 = lines.length; n < len1; n++) {
            line = lines[n];
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
      var a, arr2, b, diff, difference, end_time, end_time1, i, j, k, key, key1, len1, len2, m, maxActiveConnection, n, o, start_time, start_time1;
      fs.writeFileSync("active-tcp.txt", "", 'utf8');
      diff = 0;
      start_time = 0;
      end_time = 0;
      for (k in tcp_connections) {
        for (key in tcp_connections[k]) {
          arr = tcp_connections[k][key].slice(1);
          i = 0;
          for (n = 0, len1 = arr.length; n < len1; n++) {
            a = arr[n];
            i++;
            start_time = (new Date(a.startedDateTime)).getTime();
            end_time = start_time + a.time;
            difference = end_time - start_time;
            if (difference > diff) {
              diff = difference;
              start_time = start_time;
              end_time = end_time;
            }
          }
        }
      }
      maxActiveConnection = 0;
      for (m in tcp_connections) {
        for (key1 in tcp_connections[m]) {
          arr2 = tcp_connections[m][key1].slice(1);
          j = 0;
          for (o = 0, len2 = arr2.length; o < len2; o++) {
            b = arr2[o];
            j++;
            start_time1 = (new Date(b.startedDateTime)).getTime();
            end_time1 = start_time1 + b.time;
            if (start_time1 < end_time && end_time1 > start_time) {
              maxActiveConnection = maxActiveConnection + 1;
            }
          }
        }
      }
      return fs.appendFileSync("active-tcp.txt", "\nMaximum number of TCP connections across domain that is simultaneously active is " + maxActiveConnection + "\n", 'utf8');
    });
  };

  fun2();

}).call(this);
var http = require('http'),
    faye = require('faye');


faye.Logging.logLevel = 'debug';

var bayeux = new faye.NodeAdapter({
  mount:    '/faye',
  timeout:  45
});

// Handle non-Bayeux requests
var server = http.createServer(function(request, response) {
  response.writeHead(200, {'Content-Type': 'text/plain'});
  response.write('Non-Bayeux request');
  response.end();
});

  serverLog = {
    incoming: function(message, callback) {
      console.log("SOMETTHING HAPPENDED!");
      if (message.channel === '/meta/subscribe') {
        logWithTimeStamp("CLIENT SUBSCRIBED Client ID: " + message.clientId);
      }
      if (message.channel.match(/\/users\/*/)) {
        logWithTimeStamp("USER MESSAGE ON CHANNEL: " + message.channel);
      }
      return callback(message);
    }
  };
  logWithTimeStamp = function(logMessage) {
    var timestampedMessage;
    timestampedMessage = "" + (Date()) + " | " + logMessage;
    return console.log(timestampedMessage);
  };


bayeux.bind('handshake', function(client_id) {
  console.log("[handshake] - client: '"+ client_id +"'");
});

bayeux.bind('subscribe', function(client_id, channel) {
  console.log("[subscribe] - client: '"+ client_id +"', channel: '"+ channel +"'");
});

bayeux.bind('unsubscribe', function(client_id, channel) {
  console.log("[unsubscribe] - client: '"+ client_id +"', channel: '"+ channel +"'");
});

bayeux.bind('publish', function(client_id, channel, data) {
  console.log("[publish] - client: '"+ client_id +"', channel: '"+ channel +"'");
  console.log("[publish] - data:");
  console.log(data);
});

bayeux.bind('connect', function(client_id) {
  console.log("[connect] - client: '"+ client_id +"'");
});


bayeux.bind('disconnect', function(client_id) {
  console.log("[disconnect] - client: '"+ client_id +"'");
});

bayeux.addExtension(serverLog);
bayeux.attach(server);


bayeux.getClient().subscribe('/cool', function(message){
  console.log("OMG NEW MESSAGE CAME ***********");
  console.log(JSON.stringify(message));
});

bayeux.getClient().subscribe('/awesome', function(message){
  console.log("OMG NEW AWESOME MESSAGE CAME ***********");
  console.log(JSON.stringify(message));
});


server.listen(5222);
console.log("Started Faye Server");


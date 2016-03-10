var faye = require('faye'),
    client = new faye.Client('http://localhost:5222/faye');


faye.Logging.logLevel = 'debug';

client.publish("/cool", {"text": "ok from server nice stuff"})

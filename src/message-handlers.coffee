request = require 'request'

class MessageHandlers
  constructor: ->
    console.warn 'Implement src/message-handlers.coffee with a function per message type this endo will support'

  userRepos: ({auth, data, endo}, callback) =>
    options = {
      headers:
        'User-Agent': 'endo-github'
      auth:
        username: endo.resourceOwnerID
        password: endo.resourceOwnerSecrets.secret
      json: true
    }
    request.get 'https://api.github.com/user/repos', options, (error, response, body) =>
      return callback error if error?
      callback null, response.statusCode, body


module.exports = MessageHandlers

debug = require('debug')('endo-core:messages-controller')

class MessagesController
  constructor: ({@credentialsDeviceService, @messagesService}) ->

  create: (req, res) =>
    route   = req.get 'x-meshblu-route'
    auth    = req.meshbluAuth
    message = req.body

    debug 'create', auth.uuid
    @credentialsDeviceService.getEndoByUuid auth.uuid, (error, endo) =>
      debug 'credentialsDeviceService.getEndoByUuid', error
      return @respondWithError {auth, error, res, route} if error?

      @messagesService.send {auth, endo, message}, (error, response) =>
        debug 'messagesService.send', error
        return @respondWithError {auth, error, res, route} if error?

        @messagesService.reply {auth, route, response}, (error) =>
          debug 'messagesService.reply', error
          return @respondWithError {auth, error, res, route} if error?
          
          res.sendStatus 201

  respondWithError: ({auth, error, res, route}) =>
    @messagesService.replyWithError {auth, error, route}, (newError) =>
      return res.sendError newError if newError?
      return res.sendError error


module.exports = MessagesController

MessagesService = require '../services/messages-service'

class MessagesController
  constructor: ({@credentialsDeviceService, @messagesService}) ->

  create: (req, res) =>
    route   = req.get 'x-meshblu-route'
    auth    = req.meshbluAuth
    message = req.body

    @credentialsDeviceService.getEndoByUuid auth.uuid, (error, endo) =>
      return @respondWithError {auth, error, res, route} if error?
      @messagesService.send {auth, endo, message}, (error, code, response) =>
        return @respondWithError {auth, error, res, route} if error?
        @messagesService.reply {auth, route, code, response}, (error) =>
          return @respondWithError {auth, error, res, route} if error?
          res.sendStatus 201

  respondWithError: ({auth, error, res, route}) =>
    @messagesService.replyWithError {auth, error, route}, (newError) =>
      return res.sendError newError if newError?
      return res.sendError error


module.exports = MessagesController

_     = require 'lodash'
debug = require('debug')('endo-core:messages-controller')

class MessagesController
  constructor: ({@credentialsDeviceService, @messagesService}) ->

  create: (req, res) =>
    route     = req.get 'x-meshblu-route'
    auth      = req.meshbluAuth
    message   = req.body
    respondTo = _.get message, 'metadata.respondTo'

    debug 'create', auth.uuid
    @credentialsDeviceService.getEndoByUuid auth.uuid, (error, endo) =>
      debug 'credentialsDeviceService.getEndoByUuid', error
      return @respondWithError {auth, error, res, route, respondTo} if error?

      @messagesService.send {auth, endo, message}, (error, response) =>
        debug 'messagesService.send', error
        return @respondWithError {auth, error, res, route, respondTo} if error?

        @messagesService.reply {auth, route, response, respondTo}, (error) =>
          debug 'messagesService.reply', error
          return @respondWithError {auth, error, res, route, respondTo} if error?

          res.sendStatus 201

  respondWithError: ({auth, error, res, route, respondTo}) =>
    @messagesService.replyWithError {auth, error, route, respondTo}, (newError) =>
      return res.sendError newError if newError?
      return res.sendError error


module.exports = MessagesController

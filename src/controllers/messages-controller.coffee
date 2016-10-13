_           = require 'lodash'
debug       = require('debug')('endo-core:messages-controller')

class MessagesController
  constructor: ({@messagesService, @messageRouter}) ->

  create: (req, res) =>
    route     = JSON.parse req.get('x-meshblu-route') if req.get('x-meshblu-route')?
    auth      = req.meshbluAuth
    message   = req.body
    respondTo = _.get message, 'metadata.respondTo'

    @messageRouter.route {auth, message, route, respondTo}, (error) =>
      return @respondWithError {auth, error, res, route, respondTo} if error?
      res.sendStatus 201

  respondWithError: ({auth, error, res, route, respondTo}) =>
    @messagesService.replyWithError {auth, error, route, respondTo}, (newError) =>
      return res.sendError newError if newError?
      return res.sendError error


module.exports = MessagesController

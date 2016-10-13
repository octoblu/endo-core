RouteParser = require './route-parser'

class MessageRouter
  constructor: ({@credentialsDeviceService, @messagesService, @meshbluConfig})->

  route: ({auth, message, route, respondTo}, callback) =>
    routeParser = new RouteParser {route, serviceUuid: @meshbluConfig.uuid}
    return callback @_badRouteError() if routeParser.isBadRoute()

    {credentialsUuid, userDeviceUuid, senderUuid} = routeParser.parse()
    @credentialsDeviceService.getEndoByUuid credentialsUuid, (error, endo) =>
      return callback error if error?

      @messagesService.send {auth, userDeviceUuid, senderUuid, endo, message}, (error, response) =>
        return callback error if error?

        @messagesService.reply {auth, userDeviceUuid, senderUuid, response, respondTo}, callback

  _badRouteError: =>
    error = new Error "Bad route"
    error.code = 422
    return error

module.exports = MessageRouter

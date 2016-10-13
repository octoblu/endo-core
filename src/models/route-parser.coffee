_ = require 'lodash'

class RouteParser
  constructor: ({@route, @serviceUuid}) ->

  isBadRoute: =>
    return true if _.isEmpty @route
    userDeviceUuid = _.nth(@route, -2).from
    return _.some @route, (hop) =>
      hop.type == 'message.received' && hop.from == userDeviceUuid && hop.to == userDeviceUuid

  parse: =>
    firstHop       = _.first @route
    senderUuid     = firstHop.from
    userDeviceUuid = firstHop.to
        
    return {
      credentialsUuid: @getCredentialsDeviceUuid()
      senderUuid:     senderUuid
      userDeviceUuid: userDeviceUuid
    }

  getCredentialsDeviceUuid: =>
    return null if _.isEmpty @route
    routeWithoutService = _.reject @route, (hop) => hop.from == @serviceUuid || hop.to == @serviceUuid
    return _.last(routeWithoutService).to

  getUserDeviceUuid: =>


module.exports = RouteParser

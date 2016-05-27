MeshbluAuth = require 'express-meshblu-auth'
passport    = require 'passport'

CredentialsDeviceController = require './controllers/credentials-device-controller'
MessagesController          = require './controllers/messages-controller'
MessageSchemaController     = require './controllers/message-schema-controller'
OctobluAuthController       = require './controllers/octoblu-auth-controller'
UserDevicesController       = require './controllers/user-devices-controller'

class Router
  constructor: ({@credentialsDeviceService, @messagesService, @meshbluConfig, @serviceUrl, @userDeviceManagerUrl}) ->
    throw new Error 'credentialsDeviceService is required' unless @credentialsDeviceService?
    throw new Error 'meshbluConfig is required' unless @meshbluConfig?
    throw new Error 'messagesService is required' unless @messagesService?
    throw new Error 'serviceUrl is required' unless @serviceUrl?
    throw new Error 'userDeviceManagerUrl is required' unless @userDeviceManagerUrl?

    @credentialsDeviceController = new CredentialsDeviceController {@credentialsDeviceService, @serviceUrl, @userDeviceManagerUrl}
    @messagesController      = new MessagesController {@credentialsDeviceService, @messagesService}
    @messageSchemaController = new MessageSchemaController {@messagesService}
    @octobluAuthController   = new OctobluAuthController
    @userDevicesController   = new UserDevicesController

  route: (app) =>
    meshbluAuth = new MeshbluAuth @meshbluConfig

    app.get '/v1/message-schema', @messageSchemaController.list

    app.get '/auth/octoblu', passport.authenticate('octoblu')
    app.get '/auth/octoblu/callback', passport.authenticate('octoblu', failureRedirect: '/auth/octoblu'), @octobluAuthController.storeAuthAndRedirect

    app.use meshbluAuth.auth()
    app.use meshbluAuth.gatewayRedirect('/auth/octoblu')

    app.get  '/auth/api', passport.authenticate('api')
    app.get  '/auth/api/callback', passport.authenticate('api'), @credentialsDeviceController.upsert

    app.post '/v1/messages', @messagesController.create

    app.all  '/:credentialsDeviceUuid*', @credentialsDeviceController.getCredentialsDevice
    app.get  '/:credentialsDeviceUuid', @credentialsDeviceController.get
    app.get  '/:credentialsDeviceUuid/user-devices', @userDevicesController.list
    app.post '/:credentialsDeviceUuid/user-devices', @userDevicesController.create
    app.delete  '/:credentialsDeviceUuid/user-devices/:userDeviceUuid', @userDevicesController.delete

    app.use (req, res) => res.redirect '/auth/api'

module.exports = Router

cors               = require 'cors'
morgan             = require 'morgan'
express            = require 'express'
bodyParser         = require 'body-parser'
cookieParser       = require 'cookie-parser'
cookieSession      = require 'cookie-session'
errorHandler       = require 'errorhandler'
meshbluHealthcheck = require 'express-meshblu-healthcheck'
sendError          = require 'express-send-error'
MeshbluConfig      = require 'meshblu-config'
MeshbluHTTP       = require 'meshblu-http'
OctobluStrategy    = require 'passport-octoblu'
passport           = require 'passport'
debug              = require('debug')('endo:server')
Router             = require './router'
CredentialsDeviceService = require './services/credentials-device-service'


class Server
  constructor: (options)->
    {@apiStrategy, @deviceType, @meshbluConfig, @messageHandlers, @octobluStrategy, @serviceUrl} = options
    {@disableLogging, @logFn, @port} = options

    throw new Error('apiStrategy is required') unless @apiStrategy?
    throw new Error('deviceType is required') unless @deviceType?
    throw new Error('meshbluConfig is required') unless @meshbluConfig?
    throw new Error('messageHandlers are required') unless @messageHandlers?
    throw new Error('octobluStrategy is required') unless @octobluStrategy?
    throw new Error('serviceUrl is required') unless @serviceUrl?

  address: =>
    @server.address()

  run: (callback) =>
    passport.serializeUser   (user, done) => done null, user
    passport.deserializeUser (user, done) => done null, user

    passport.use 'octoblu', @octobluStrategy
    passport.use 'api', @apiStrategy

    app = express()
    app.use meshbluHealthcheck()
    app.use morgan 'dev', immediate: false unless @disableLogging
    app.use cors()
    app.use errorHandler()
    app.use cookieSession secret: 'here, kitty, kitty'# @meshbluConfig.token
    app.use cookieParser()
    app.use passport.initialize()
    app.use passport.session()
    app.use bodyParser.urlencoded limit: '1mb', extended : true
    app.use bodyParser.json limit : '1mb'
    app.use sendError {@logFn}
    app.options '*', cors()

    meshblu = new MeshbluHTTP @meshbluConfig
    meshblu.whoami (error, device) =>
      throw new Error('Could not authenticate with meshblu!') if error?
      {imageUrl} = device.options
      credentialsDeviceService = new CredentialsDeviceService {@deviceType, imageUrl, @meshbluConfig, @serviceUrl}

      router = new Router {credentialsDeviceService, @meshbluConfig, @messageHandlers}
      router.route app

      @server = app.listen @port, callback

  stop: (callback) =>
    @server.close callback

module.exports = Server

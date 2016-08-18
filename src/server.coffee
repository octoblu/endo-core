cors               = require 'cors'
morgan             = require 'morgan'
express            = require 'express'
bodyParser         = require 'body-parser'
cookieParser       = require 'cookie-parser'
cookieSession      = require 'cookie-session'
errorHandler       = require 'errorhandler'
meshbluHealthcheck = require 'express-meshblu-healthcheck'
sendError          = require 'express-send-error'
MeshbluHTTP        = require 'meshblu-http'
path               = require 'path'
passport           = require 'passport'
favicon            = require 'serve-favicon'
expressVersion     = require 'express-package-version'

Router                   = require './router'
CredentialsDeviceService = require './services/credentials-device-service'
MessagesService          = require './services/messages-service'

class Server
  constructor: (options)->
    {
      @apiStrategy
      @appOctobluHost
      @deviceType
      @meshbluConfig
      @messageHandler
      @octobluStrategy
      @schemas
      @serviceUrl
      @userDeviceManagerUrl
      @disableLogging
      @logFn
      @port
      @staticSchemasPath
      @skipRedirectAfterApiAuth
    } = options

    throw new Error('apiStrategy is required') unless @apiStrategy?
    throw new Error('appOctobluHost is required') unless @appOctobluHost?
    throw new Error('deviceType is required') unless @deviceType?
    throw new Error('meshbluConfig is required') unless @meshbluConfig?
    throw new Error('messageHandler is required') unless @messageHandler?
    throw new Error('octobluStrategy is required') unless @octobluStrategy?
    throw new Error('schemas not allowed') if @schemas?
    throw new Error('serviceUrl is required') unless @serviceUrl?
    throw new Error('userDeviceManagerUrl is required') unless @userDeviceManagerUrl?

  address: =>
    @server.address()

  run: (callback) =>
    passport.serializeUser   (user, done) => done null, user
    passport.deserializeUser (user, done) => done null, user

    passport.use 'octoblu', @octobluStrategy
    passport.use 'api', @apiStrategy

    app = express()
    app.use favicon path.join(__dirname, '../favicon.ico')
    app.use meshbluHealthcheck()
    app.use expressVersion format: '{"version": "%s"}'
    app.use morgan 'dev', immediate: false unless @disableLogging
    app.use cors(exposedHeaders: ['Location'])
    app.use errorHandler()
    app.use cookieSession secret: @meshbluConfig.token
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
      {imageUrl} = device.options ? {}
      credentialsDeviceService  = new CredentialsDeviceService {@deviceType, imageUrl, @meshbluConfig, @serviceUrl}
      messagesService           = new MessagesService {@messageHandler, @schemas}
      router = new Router {
        credentialsDeviceService
        messagesService
        @appOctobluHost
        @meshbluConfig
        @serviceUrl
        @userDeviceManagerUrl
        @staticSchemasPath
        @skipRedirectAfterApiAuth
      }
      router.route app

      @server = app.listen @port, callback

  stop: (callback) =>
    @server.close callback

module.exports = Server

{afterEach, beforeEach, describe, it} = global
{expect} = require 'chai'
sinon    = require 'sinon'

fs            = require 'fs'
Encryption    = require 'meshblu-encryption'
path          = require 'path'
request       = require 'request'
enableDestroy = require 'server-destroy'
shmock        = require 'shmock'

MockStrategy  = require '../mock-strategy'
Server        = require '../../src/server'

describe 'static schemas', ->
  beforeEach (done) ->
    @privateKey = fs.readFileSync "#{__dirname}/../data/private-key.pem", 'utf8'
    @encryption = Encryption.fromPem @privateKey
    encrypted =
      secrets:
        credentials:
          secret: 'this is secret'

    @encrypted = @encryption.encrypt encrypted
    @publicKey = @encryption.key.exportKey 'public'


    @meshblu = shmock 0xd00d
    enableDestroy @meshblu
    @apiStrategy = new MockStrategy name: 'api'
    @octobluStrategy = new MockStrategy name: 'octoblu'
    @messageHandler = messageSchema: sinon.stub()

    @meshblu
      .get '/v2/whoami'
      .set 'Authorization', "Basic cGV0ZXI6aS1jb3VsZC1lYXQ="
      .reply 200, {
        options:
          imageUrl: "http://this-is-an-image.exe"
      }

    @meshblu
      .get '/publickey'
      .reply 200, {@publicKey}

    serverOptions =
      logFn: ->
      port: undefined,
      disableLogging: true
      apiStrategy: @apiStrategy
      octobluStrategy: @octobluStrategy
      messageHandler: @messageHandler
      serviceUrl: 'http://octoblu.xxx'
      deviceType: 'endo-endor'
      meshbluConfig:
        server: 'localhost'
        port: 0xd00d
        uuid: 'peter'
        token: 'i-could-eat'
        privateKey: @privateKey
      appOctobluHost: 'http://app.octoblu.xxx'
      userDeviceManagerUrl: 'http://manage-my.endo'
      staticSchemasPath: path.join(__dirname, '../fixtures/schemas')
      meshbluPublicKeyUri: 'http://localhost:53261/publickey'

    @server = new Server serverOptions

    @server.run (error) =>
      return done error if error?
      @serverPort = @server.address().port
      done()

  afterEach (done) ->
    @server.stop done

  afterEach (done) ->
    @meshblu.destroy done

  describe 'On GET /schemas/non-extant', ->
    describe 'When no non-extant.cson or non-extant.json file is available', ->
      beforeEach (done) ->
        options =
          json: true
          baseUrl: "http://localhost:#{@server.address().port}"
        request.get '/schemas/non-extant', options, (error, @response, @body) =>
          done error

      it 'should return a 404', ->
        expect(@response.statusCode).to.equal 404, JSON.stringify @body

      it 'should return an error', ->
        expect(@body).to.deep.equal {error: 'Could not find a schema for that path'}

  describe 'On GET /schemas/configure', ->
    describe 'When configure.cson is available at <path>/configure.cson', ->
      beforeEach (done) ->
        options =
          json: true
          baseUrl: "http://localhost:#{@server.address().port}"

        request.get '/schemas/configure', options, (error, @response, @body) =>
          done error

      it 'should return a 200', ->
        expect(@response.statusCode).to.equal 200, JSON.stringify @body

      it 'should return the configure schema', ->
        expect(@body).to.deep.equal {foo: 'bar'}

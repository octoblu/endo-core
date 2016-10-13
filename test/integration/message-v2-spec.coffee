{afterEach, beforeEach, describe, it} = global
{expect} = require 'chai'
sinon    = require 'sinon'

fs            = require 'fs'
request       = require 'request'
Encryption    = require 'meshblu-encryption'
enableDestroy = require 'server-destroy'
shmock        = require 'shmock'

MockStrategy  = require '../mock-strategy'
Server        = require '../../src/server'

describe 'v2 messages', ->
  beforeEach (done) ->
    @privateKey = fs.readFileSync "#{__dirname}/../data/private-key.pem", 'utf8'
    @encryption = Encryption.fromPem @privateKey
    @publicKey = @encryption.key.exportKey 'public'

    encrypted =
      secrets:
        credentials:
          secret: 'this is secret'
    @encrypted = @encryption.encrypt encrypted

    @meshblu = shmock 0xd00d
    enableDestroy @meshblu
    @apiStrategy = new MockStrategy name: 'api'
    @octobluStrategy = new MockStrategy name: 'octoblu'
    @messageHandler = onMessage: sinon.stub()

    @meshblu
      .get 'publickey'
      .reply 200, @privateKey

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
      appOctobluHost: 'http://app.octoblu.mom'
      userDeviceManagerUrl: 'http://manage-my.endo'
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

  describe 'On POST /v2/messages', ->
    describe 'when not signed by meshblu', ->
      beforeEach (done) ->
        options =
          baseUrl: "http://localhost:#{@serverPort}"
          headers:
            'x-meshblu-route': JSON.stringify [
              {"from": "flow-uuid", "to": "user-uuid", "type": "message.sent"}
              {"from": "user-uuid", "to": "cred-uuid", "type": "message.received"}
              {"from": "cred-uuid", "to": "cred-uuid", "type": "message.received"}
            ]
          json:
            metadata:
              jobType: 'hello'
            data:
              greeting: 'hola'
          auth:
            username: 'cred-uuid'
            password: 'cred-token'

        request.post '/v2/messages', options, (error, @response) =>
          done error

      it "should not do anything, because the signature doesn't exist", ->
        expect(@response).not.to.exist

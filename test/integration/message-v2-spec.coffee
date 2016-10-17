{afterEach, beforeEach, describe, it} = global
{expect} = require 'chai'
sinon    = require 'sinon'

fs            = require 'fs'
request       = require 'request'
Encryption    = require 'meshblu-encryption'
enableDestroy = require 'server-destroy'
shmock        = require 'shmock'

MockStrategy  = require '../mock-strategy'
Server        = require '../..'
describe 'v2 messages', ->
  beforeEach (done) ->
    @serviceAuth = new Buffer('peter:i-could-eat').toString 'base64'
    @privateKey = fs.readFileSync "#{__dirname}/../data/private-key.pem", 'utf8'
    @HTTP_SIGNATURE_OPTIONS =
      keyId: 'meshblu-webhook-key'
      key: @privateKey
      headers: [ 'date', 'X-MESHBLU-UUID' ]

    @encryption = Encryption.fromPem @privateKey
    @publicKey = @encryption.key.exportKey 'public'

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
      .set 'Authorization', "Basic #{@serviceAuth}"
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
        hostname: 'localhost'
        protocol: 'http'
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
            'x-meshblu-uuid': 'peter'
            'x-meshblu-route': JSON.stringify [
              {"from": "flow-uuid", "to": "user-uuid", "type": "message.sent"}
              {"from": "user-uuid", "to": "cred-uuid", "type": "message.received"}
              {"from": "cred-uuid", "to": "cred-uuid", "type": "message.received"}
              {"from": "cred-uuid", "to": "peter", "type": "message.received"}
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

      it "should return a 401, because the signature doesn't exist", ->
        expect(@response.statusCode).to.equal 401

    describe 'when signed by meshblu, but for the wrong uuid', ->
      beforeEach (done) ->
        options =
          httpSignature: @HTTP_SIGNATURE_OPTIONS
          baseUrl: "http://localhost:#{@serverPort}"
          headers:
            'x-meshblu-uuid': 'Pumpkin Eater'
            'x-meshblu-route': JSON.stringify [
              {"from": "flow-uuid", "to": "user-uuid", "type": "message.sent"}
              {"from": "user-uuid", "to": "cred-uuid", "type": "message.received"}
              {"from": "cred-uuid", "to": "cred-uuid", "type": "message.received"}
              {"from": "cred-uuid", "to": "peter", "type": "message.received"}
            ]
          json:
            metadata:
              jobType: 'hello'
            data:
              greeting: 'hola'

        request.post '/v2/messages', options, (error, @response) =>
          done error

      it "should return a 401, because that webhook is for someone else", ->
        expect(@response.statusCode).to.equal 401

    describe 'when signed by meshblu, for the service', ->
      beforeEach 'requestOptions', ->
        @requestOptions =
          httpSignature: @HTTP_SIGNATURE_OPTIONS
          baseUrl: "http://localhost:#{@serverPort}"
          headers:
            'x-meshblu-uuid': 'peter'
            'x-meshblu-route': JSON.stringify [
              {"from": "flow-uuid", "to": "user-uuid", "type": "message.sent"}
              {"from": "user-uuid", "to": "cred-uuid", "type": "message.received"}
              {"from": "cred-uuid", "to": "cred-uuid", "type": "message.received"}
              {"from": "cred-uuid", "to": "peter", "type": "message.received"}
            ]
          json:
            metadata:
              jobType: 'hello'
              respondTo: foo: 'bar'
            data:
              greeting: 'hola'

      describe "but the credentials device doesn't have an encrypted token for the service", ->
        beforeEach 'credentials-device', ->
          unencrypted =
            secrets:
              credentials:
                secret: 'this is secret'
          endo =
            authorizedKey: 'some-uuid'
            credentialsDeviceUuid: 'cred-uuid'
            encrypted: @encryption.encrypt unencrypted

          endoSignature = @encryption.sign {
            authorizedKey: 'some-uuid'
            credentialsDeviceUuid: 'cred-uuid'
            encrypted: unencrypted
          }

          @meshblu
            .get '/v2/devices/cred-uuid'
            .set 'Authorization', "Basic #{@serviceAuth}"
            .reply 200,
              uuid: 'cred-uuid'
              endoSignature: endoSignature
              endo: endo

        beforeEach (done) ->
          request.post '/v2/messages', @requestOptions, (error, @response) =>
            done error

        it "should return a 422, because the credentials device is misconfigured", ->
          expect(@response.statusCode).to.equal 422

      describe "and the credentials device has an encrypted token", ->
        beforeEach 'credentials-device', ->
          unencrypted =
            secrets:
              credentialsDeviceToken: 'cred-token'
              credentials:
                secret: 'this is secret'
          endo =
            authorizedKey: 'some-uuid'
            credentialsDeviceUuid: 'cred-uuid'
            encrypted: @encryption.encrypt unencrypted

          endoSignature = @encryption.sign {
            authorizedKey: 'some-uuid'
            credentialsDeviceUuid: 'cred-uuid'
            encrypted: unencrypted
          }

          @meshblu
            .get '/v2/devices/cred-uuid'
            .set 'Authorization', "Basic #{@serviceAuth}"
            .reply 200,
              uuid: 'cred-uuid'
              endoSignature: endoSignature
              endo: endo

        beforeEach (done) ->
          credentialsDeviceAuth = new Buffer('cred-uuid:cred-token').toString 'base64'
          @messageHandler.onMessage.yields null, metadata: {code: 200}, data: {whatever: 'this is a response'}
          @responseHandler = @meshblu
            .post '/messages'
            .set 'Authorization', "Basic #{credentialsDeviceAuth}"
            .set 'x-meshblu-as', 'user-uuid'
            .send
              devices: ['flow-uuid']
              metadata:
                code: 200
                to: { foo: 'bar' }
              data:
                whatever: 'this is a response'
            .reply 201

          request.post '/v2/messages', @requestOptions, (error, @response) => done error

        it 'should return a 201', ->
          expect(@response.statusCode).to.equal 201

        it 'should respond to the message via meshblu', ->
          @responseHandler.done()

        it 'should call the hello messageHandler with the message and auth', ->
          expect(@messageHandler.onMessage).to.have.been.calledWith {
            encrypted:
              secrets:
                credentials:
                  secret: 'this is secret'
            metadata:
              jobType: 'hello'
              respondTo: foo: 'bar'
            data:
              greeting: 'hola'
          }

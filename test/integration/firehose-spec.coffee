{afterEach, beforeEach, describe, it} = global
{expect} = require 'chai'
sinon    = require 'sinon'

fs            = require 'fs'
request       = require 'request'
URL           = require 'url'
Encryption    = require 'meshblu-encryption'
enableDestroy = require 'server-destroy'
shmock        = require 'shmock'
SocketIO      = require 'socket.io'
MockStrategy  = require '../mock-strategy'
Endo          = require '../..'
_             = require 'lodash'
describe 'firehose', ->
  beforeEach 'setup socket.io', ->
    @firehoseServer = new SocketIO 0xcaf1

  afterEach ->
    @firehoseServer.close()

  beforeEach 'setup meshblu http', ->
    @serviceAuth = new Buffer('peter:i-could-eat').toString 'base64'
    @privateKey = fs.readFileSync "#{__dirname}/../data/private-key.pem", 'utf8'

    @encryption = Encryption.fromPem @privateKey
    @publicKey = @encryption.key.exportKey 'public'

    @meshblu = shmock 0xd00d
    enableDestroy @meshblu

    class MessageHandler
      _onMessage: sinon.stub()

      onMessage: (data, callback) =>
        @_onMessage data, callback
        @done() if @done?

    @messageHandler = new MessageHandler()

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

  afterEach (done) ->
    @meshblu.destroy done

  beforeEach 'setup sut', ->
    options =
      logFn: ->
      messageHandler: @messageHandler
      serviceUrl: 'http://octoblu.xxx'
      deviceType: 'endo-endor'
      skipExpress: true
      useFirehose: true
      meshbluConfig:
        hostname: 'localhost'
        protocol: 'http'
        port: 0xd00d
        uuid: 'peter'
        token: 'i-could-eat'
        privateKey: @privateKey
      firehoseMeshbluConfig:
        hostname: 'localhost'
        protocol: 'http'
        port: 0xcaf1
        uuid: 'peter'
        token: 'i-could-eat'
        privateKey: @privateKey

    @sut = new Endo options

  afterEach (done) ->
    @sut.stop done

  describe '->run', ->
    beforeEach (done) ->
      @firehoseServer.on 'connection', (@socket) =>
        {@pathname, @query} = URL.parse @socket.client.request.url, true
        @uuid = @socket.client.request.headers['x-meshblu-uuid']
        @token = @socket.client.request.headers['x-meshblu-token']
        done()

      @sut.run =>

    it 'should connect', ->
      expect(@socket).to.exist
      expect(@pathname).to.equal '/socket.io/v1/peter/'

    it 'should pass along the auth info', ->
      expect(@uuid).to.equal 'peter'
      expect(@token).to.equal 'i-could-eat'
      expect(@query.uuid).to.equal 'peter'
      expect(@query.token).to.equal 'i-could-eat'

    describe 'when the credentials device has an encrypted token', ->
      beforeEach 'message', ->
        @message =
          metadata:
            route: [
              {"from": "flow-uuid", "to": "user-uuid", "type": "message.sent"}
              {"from": "user-uuid", "to": "cred-uuid", "type": "message.received"}
              {"from": "cred-uuid", "to": "cred-uuid", "type": "message.received"}
              {"from": "cred-uuid", "to": "peter",     "type": "message.received"}
            ]
          rawData: JSON.stringify(
            metadata:
              jobType: 'hello'
              respondTo: foo: 'bar'
            data:
              greeting: 'hola'
          )

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
          .post '/search/devices'
          .set 'Authorization', "Basic #{@serviceAuth}"
          .set 'x-meshblu-as', 'cred-uuid'
          .send uuid: 'cred-uuid'
          .reply 200, [
            uuid: 'cred-uuid'
            endoSignature: endoSignature
            endo: endo
          ]

      beforeEach (done) ->
        credentialsDeviceAuth = new Buffer('cred-uuid:cred-token').toString 'base64'

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

        @socket.emit 'message', @message
        @messageHandler.done = _.once done
        @messageHandler._onMessage.yields null, metadata: {code: 200}, data: {whatever: 'this is a response'}

      it 'should respond to the message via meshblu', (done)->
        @responseHandler.wait(1000, done)

      it 'should call the hello messageHandler with the message and auth', ->
        expect(@messageHandler._onMessage).to.have.been.calledWith {
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

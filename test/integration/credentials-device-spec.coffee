{afterEach, beforeEach, describe, it} = global
{expect} = require 'chai'

fs           = require 'fs'
request      = require 'request'
shmock       = require '@octoblu/shmock'
MockStrategy = require '../mock-strategy'
Server       = require '../../src/server'
Encryption   = require 'meshblu-encryption'

describe 'Credentials Device Spec', ->
  beforeEach (done) ->
    @meshblu = shmock 0xd00d
    @privateKey = fs.readFileSync "#{__dirname}/../data/private-key.pem", 'utf8'

    encryption = Encryption.fromPem @privateKey
    @encrypted = encryption.encrypt username: 'sqrtofsaturn', secrets: {}

    @apiStrategy = new MockStrategy {name: 'lib'}
    @octobluStrategy = new MockStrategy {name: 'octoblu'}

    serverOptions =
      logFn: ->
      messageHandler: {}
      port: undefined,
      disableLogging: true
      apiStrategy: @apiStrategy
      apiName: 'github'
      deviceType: 'endo-core'
      octobluStrategy: @octobluStrategy
      serviceUrl: 'http://octoblu.xxx'
      meshbluConfig:
        server: 'localhost'
        port: 0xd00d
        uuid: 'service-uuid'
        token: 'service-token'
        privateKey: @privateKey
      userDeviceManagerUrl: 'http://manage-my.endo'

    serviceAuth = new Buffer('service-uuid:service-token').toString 'base64'
    @meshblu
      .get '/v2/whoami'
      .set 'Authorization', "Basic #{serviceAuth}"
      .reply 200, {
        options:
          imageUrl: "http://this-is-an-image.exe"
      }

    @server = new Server serverOptions

    @server.run (error) =>
      return done error if error?
      @serverPort = @server.address().port
      done()

  afterEach (done) ->
    @server.stop done

  afterEach (done) ->
    @meshblu.close done

  describe 'On GET /cred-uuid', ->
    describe 'when authorized', ->
      beforeEach (done) ->
        userAuth = new Buffer('user-uuid:user-token').toString 'base64'
        serviceAuth = new Buffer('service-uuid:service-token').toString 'base64'
        credentialsDeviceAuth = new Buffer('cred-uuid:cred-token2').toString 'base64'

        @meshblu
          .post '/authenticate'
          .set 'Authorization', "Basic #{userAuth}"
          .reply 204

        @meshblu
          .post '/search/devices'
          .send uuid: 'cred-uuid', 'endo.authorizedKey': "LF0GppVttGA+pNVhaRQ9zUOVQBP+e0jJCu3MDA0hQrbDQ3+lDWui1SQ2cpTyA0KtZ1hyFGtAi5AoL39knIxtaQ=="
          .set 'Authorization', "Basic #{serviceAuth}"
          .reply 200, [
            uuid: 'cred-uuid'
            endoSignature: 'dg5gJq4J6mNvdwy3l6l6IgeeCzdi7gSnEUmGObyB+6YswwaqYqsYS1y1Y2aWXWZcT+gEzS5zW7iB4Ii0if5CKg=='
            endo:
              authorizedKey: 'user-uuid'
              credentialsDeviceUuid: 'cred-uuid'
              encrypted: @encrypted
          ]

        @meshblu
          .post '/devices/cred-uuid/tokens'
          .set 'Authorization', "Basic #{serviceAuth}"
          .reply 200, uuid: 'cred-uuid', token: 'cred-token2'

        @meshblu
          .get '/v2/devices/service-uuid'
          .set 'Authorization', "Basic #{credentialsDeviceAuth}"
          .reply 200, {
            uuid: 'service-uuid'
            options:
              name: 'API Name'
              imageUrl: 'http://bit.ly/1SDctTa'
          }

        options =
          baseUrl: "http://localhost:#{@serverPort}"
          followRedirect: false
          json: true
          auth:
            username: 'user-uuid'
            password: 'user-token'

        request.get '/cred-uuid', options, (error, @response, @body) =>
          done error

      it 'should return a 200', ->
        expect(@response.statusCode).to.equal 200, JSON.stringify(@body)

      it 'should return a public version of the credentials device', ->
        expect(@body).to.deep.equal {
          name: 'API Name'
          imageUrl: 'http://bit.ly/1SDctTa'
          username: 'sqrtofsaturn'
        }

    describe 'when inauthentic', ->
      beforeEach (done) ->
        userAuth = new Buffer('user-uuid:user-token').toString 'base64'
        serviceAuth = new Buffer('service-uuid:service-token').toString 'base64'

        @meshblu
          .post '/authenticate'
          .set 'Authorization', "Basic #{userAuth}"
          .reply 204

        @meshblu
          .post '/search/devices'
          .send uuid: 'cred-uuid', 'endo.authorizedKey': 'LF0GppVttGA+pNVhaRQ9zUOVQBP+e0jJCu3MDA0hQrbDQ3+lDWui1SQ2cpTyA0KtZ1hyFGtAi5AoL39knIxtaQ=='
          .set 'Authorization', "Basic #{serviceAuth}"
          .reply 200, []

        @meshblu
          .post '/devices/cred-uuid/tokens'
          .set 'Authorization', "Basic #{serviceAuth}"
          .reply 200, uuid: 'cred-uuid', token: 'cred-token2'

        options =
          baseUrl: "http://localhost:#{@serverPort}"
          json: true
          auth:
            username: 'user-uuid'
            password: 'user-token'

        request.get '/cred-uuid/user-devices', options, (error, @response, @body) =>
          done error

      it 'should return a 404', ->
        expect(@response.statusCode).to.equal 404

    describe 'when authorized, but with a bad credentials device', ->
      beforeEach (done) ->
        userAuth = new Buffer('user-uuid:user-token').toString 'base64'
        serviceAuth = new Buffer('service-uuid:service-token').toString 'base64'

        @meshblu
          .post '/authenticate'
          .set 'Authorization', "Basic #{userAuth}"
          .reply 204

        @meshblu
          .post '/search/devices'
          .send uuid: 'bad-cred-uuid', 'endo.authorizedKey': "LF0GppVttGA+pNVhaRQ9zUOVQBP+e0jJCu3MDA0hQrbDQ3+lDWui1SQ2cpTyA0KtZ1hyFGtAi5AoL39knIxtaQ=="
          .set 'Authorization', "Basic #{serviceAuth}"
          .reply 200, [
            uuid: 'bad-cred-uuid'
            endo:
              authorizedKey: 'user-uuid'
              credentialsDeviceUuid: 'cred-uuid'
              encrypted: @encrypted
          ]

        options =
          baseUrl: "http://localhost:#{@serverPort}"
          json: true
          auth:
            username: 'user-uuid'
            password: 'user-token'

        request.get '/bad-cred-uuid/user-devices', options, (error, @response, @body) =>
          done error

      it 'should return a 404', ->
        expect(@response.statusCode).to.equal 404, JSON.stringify @body

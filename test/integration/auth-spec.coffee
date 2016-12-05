{afterEach, beforeEach, describe, it} = global
{expect}                   = require 'chai'
sinon                      = require 'sinon'

fs            = require 'fs'
Encryption    = require 'meshblu-encryption'
request       = require 'request'
enableDestroy = require 'server-destroy'
shmock        = require 'shmock'
MockStrategy  = require '../mock-strategy'
Server        = require '../..'

describe 'Auth Spec', ->
  beforeEach (done) ->
    @privateKey             = fs.readFileSync "#{__dirname}/../data/private-key.pem", 'utf8'
    encryption              = Encryption.fromPem @privateKey
    @publicKey              = encryption.key.exportKey 'public'
    @encryptedSecrets       = encryption.encrypt {
      credentialsDeviceToken: 'cred-token2'
      credentials:
        secret:       'resource owner secret'
        refreshToken: 'resource owner refresh token'
    }
    @resourceOwnerSignature = 'Ula5075pW5J6pbIzhez3Be78UsyVApbXMXEPXmMwBAtVdtxdHoXNx+fI9nLV/pHZzlOI0RjhJmO+qQ3zAnKviw=='

    decryptClientSecret = (req, res, next) =>
      return next() unless req.body?.$set?['endo']?['encrypted']?
      req.body.$set['endo']['encrypted'] = encryption.decrypt req.body.$set['endo']['encrypted']
      next()

    @meshblu = shmock 0xd00d, [decryptClientSecret]
    @meshblu
      .get '/publickey'
      .reply 200, {@publicKey}

    enableDestroy @meshblu

    @apiStub = sinon.stub().yields(new Error('Unauthorized'))
    @apiStrategy = new MockStrategy name: 'api', @apiStub
    @octobluStub = sinon.stub().yields(new Error('Unauthorized'))
    @octobluStrategy = new MockStrategy name: 'octoblu', @octobluStub
    @meshblu
      .get '/v2/whoami'
      .set 'Authorization', "Basic cGV0ZXI6aS1jb3VsZC1lYXQ="
      .reply 200, {
        options:
          imageUrl: "http://this-is-an-image.exe"
      }

    serverOptions =
      logFn: -> console.log arguments...
      messageHandler: {}
      deviceType: 'endo-app'
      apiStrategy: @apiStrategy
      octobluStrategy: @octobluStrategy
      disableLogging: true
      meshbluConfig:
        hostname: 'localhost'
        protocol: 'http'
        port: 0xd00d
        uuid: 'peter'
        token: 'i-could-eat'
        privateKey: @privateKey
      port: undefined,
      serviceUrl: "http://the-endo-url"
      userDeviceManagerUrl: 'http://manage-my.endo'
      appOctobluHost: 'http://app.octoblu.biz/'
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

  describe 'When inauthenticated', ->
    describe 'On GET /', ->
      beforeEach (done) ->
        options =
          baseUrl: "http://localhost:#{@serverPort}"
          followRedirect: false

        request.get '/', options, (error, @response, @body) =>
          done error

      it 'should return a 302', ->
        expect(@response.statusCode).to.equal 302, @body

      it 'should redirect to /auth/octoblu', ->
        expect(@response.headers.location).to.equal '/auth/octoblu'

    describe 'On GET /auth/octoblu', ->
      beforeEach (done) ->
        options =
          baseUrl: "http://localhost:#{@serverPort}"
          followRedirect: false

        request.get '/auth/octoblu', options, (error, @response, @body) =>
          done error

      it 'should return a 302', ->
        expect(@response.statusCode).to.equal 302, @body

    describe 'On GET /auth/octoblu/callback with a valid code', ->
      beforeEach (done) ->
        @octobluStub.yields null, {
          uuid: 'u'
          bearerToken: 'grizzly'
        }

        @meshblu
          .get '/v2/whoami'
          .set 'Authorization', "Bearer grizzly"
          .reply 200, {}

        options =
          baseUrl: "http://localhost:#{@serverPort}"
          followRedirect: false
          qs:
            code: new Buffer('client-id:u:t1').toString 'base64'

        request.get '/auth/octoblu/callback', options, (error, @response, @body) =>
          done error

      it 'should return a 302', ->
        expect(@response.statusCode).to.equal 302

      it 'should redirect to /auth/api', ->
        expect(@response.headers.location).to.equal '/auth/api'

      it 'should set the meshblu auth cookies', ->
        expect(@response.headers['set-cookie']).to.contain 'meshblu_auth_bearer=grizzly; Path=/'

  describe 'On GET /auth/api', ->
    beforeEach (done) ->
      userAuth = new Buffer('some-uuid:some-token').toString 'base64'

      @authDevice = @meshblu
        .post '/authenticate'
        .set 'Authorization', "Basic #{userAuth}"
        .reply 204

      options =
        uri: '/auth/api'
        baseUrl: "http://localhost:#{@serverPort}"
        followRedirect: false
        auth:
          username: 'some-uuid'
          password: 'some-token'

      request.get options, (error, @response, @body) =>
        done error

    it 'should auth the octoblu device', ->
      @authDevice.done()

    it 'should return a 302', ->
      expect(@response.statusCode).to.equal 302

  describe 'On GET /auth/api/callback', ->
    describe 'when the credentials device does not exist', ->
      beforeEach ->
        @apiStub.yields null, {
          id:       'resource owner id'
          username: 'resource owner username'
          secrets:
            credentials:
              secret:       'resource owner secret'
              refreshToken: 'resource owner refresh token'
        }

        userAuth = new Buffer('some-uuid:some-token').toString 'base64'
        serviceAuth = new Buffer('peter:i-could-eat').toString 'base64'
        credentialsDeviceAuth = new Buffer('cred-uuid:cred-token2').toString 'base64'

        @meshblu
          .post '/authenticate'
          .set 'Authorization', "Basic #{userAuth}"
          .reply 204

        @meshblu
          .post '/search/devices'
          .set 'Authorization', "Basic #{serviceAuth}"
          .send
            'endo.idKey': 'Ula5075pW5J6pbIzhez3Be78UsyVApbXMXEPXmMwBAtVdtxdHoXNx+fI9nLV/pHZzlOI0RjhJmO+qQ3zAnKviw=='
          .reply 200, []

        @createCredentialsDevice = @meshblu
          .post '/devices'
          .set 'Authorization', "Basic #{serviceAuth}"
          .send
            meshblu:
              version: '2.0.0'
              whitelists:
                discover:
                  view: [{uuid: 'peter'}]
                  as: [{uuid: 'peter'}]
                configure:
                  update: [{uuid: 'peter'}]
                message:
                  received: [{uuid: 'peter'}]
          .reply 200, uuid: 'cred-uuid', token: 'cred-token'

        @meshblu
          .post '/devices/cred-uuid/tokens'
          .set 'Authorization', "Basic #{serviceAuth}"
          .reply 201, '{"uuid": "cred-uuid", "token": "cred-token2"}'

        @updateCredentialsDevice = @meshblu
          .put '/v2/devices/cred-uuid'
          .set 'Authorization', "Basic #{credentialsDeviceAuth}"
          .send
            $set:
              endo:
                authorizedKey: 'pG7eYd4TYZOX2R5S73jo9aexPzldiNo4pw1wViDpYrAAGRMT6dY0jlbXbfHMz9y+El6AcXMZJEOxaeO1lITsYg=='
                idKey: 'Ula5075pW5J6pbIzhez3Be78UsyVApbXMXEPXmMwBAtVdtxdHoXNx+fI9nLV/pHZzlOI0RjhJmO+qQ3zAnKviw=='
                credentialsDeviceUuid: 'cred-uuid'
                version: '1.0.0'
                encrypted:
                  id:           'resource owner id'
                  username:     'resource owner username'
                  secrets:
                    credentialsDeviceToken: 'cred-token2'
                    credentials:
                      secret:       'resource owner secret'
                      refreshToken: 'resource owner refresh token'
              endoSignature: 'i7OF2Kc6ReZ2EKpDRLgyt/VlyxilV7nes+36ib6zsqe6i90RkZ2IF9JRFhEcwWbt4/JYUpZcfr1YhODtGH769g=='
          .reply 204

        @createMessageReceivedSubscription = @meshblu
          .post '/v2/devices/peter/subscriptions/cred-uuid/message.received'
          .set 'Authorization', "Basic #{serviceAuth}"
          .reply 201

      describe 'when called without an accept header', ->
        beforeEach (done) ->
          options =
            uri: '/auth/api/callback'
            baseUrl: "http://localhost:#{@serverPort}"
            followRedirect: false
            auth:
              username: 'some-uuid'
              password: 'some-token'

          request.get options, (error, @response, @body) =>
            done error

        it 'should return a 301', ->
          expect(@response.statusCode).to.equal 301, @body

        it 'should create a credentials device', ->
          @createCredentialsDevice.done()

        it 'should update the credentials device with the new resourceOwnerSecret and authorizedUuid', ->
          @updateCredentialsDevice.done()

        it "should subscribe the service to the credential's received messages", ->
          @createMessageReceivedSubscription.done()

        it 'should redirect to the userDeviceManagerUrl with the bearerToken and credentialsDeviceUrl', ->
          UNEXPECTED = 'http://manage-my.endo/?meshbluAuthBearer=c29tZS11dWlkOnNvbWUtdG9rZW4%3D&credentialsDeviceUrl=http%3A%2F%2Fthe-endo-url%2Fcredentials%2Fcred-uuid&appOctobluHost=http%3A%2F%2Fapp.octoblu.biz%2F'
          expect(@response.headers.location).to.equal UNEXPECTED

      describe 'when called with a JSON accept header', ->
        beforeEach (done) ->
          options =
            uri: '/auth/api/callback'
            baseUrl: "http://localhost:#{@serverPort}"
            followRedirect: false
            json: true
            headers:
              Accept: 'application/json'
            auth:
              username: 'some-uuid'
              password: 'some-token'

          request.get options, (error, @response, @body) =>
            done error

        it 'should return a 201', ->
          expect(@response.statusCode).to.equal 201, @body

        it 'should create a credentials device', ->
          @createCredentialsDevice.done()

        it 'should update the credentials device with the new resourceOwnerSecret and authorizedUuid', ->
          @updateCredentialsDevice.done()

        it "should subscribe the service to the credential's received messages", ->
          @createMessageReceivedSubscription.done()

        it 'should return the credentials device uuid', ->
          expect(@body).to.deep.equal uuid: 'cred-uuid'

    describe 'when the credentials device does exist', ->
      beforeEach (done) ->
        userAuth = new Buffer('some-uuid:some-token').toString 'base64'
        serviceAuth = new Buffer('peter:i-could-eat').toString 'base64'
        credentialsDeviceAuth = new Buffer('cred-uuid:cred-token2').toString 'base64'

        @apiStub.yields null, {
          id:       'resource owner id'
          username: 'resource owner username'
          secrets:
            credentials:
              secret:       'resource owner secret'
              refreshToken: 'resource owner refresh token'
        }

        @meshblu
          .post '/authenticate'
          .set 'Authorization', "Basic #{userAuth}"
          .reply 204

        @meshblu
          .post '/search/devices'
          .set 'Authorization', "Basic #{serviceAuth}"
          .send 'endo.idKey': 'Ula5075pW5J6pbIzhez3Be78UsyVApbXMXEPXmMwBAtVdtxdHoXNx+fI9nLV/pHZzlOI0RjhJmO+qQ3zAnKviw=='
          .reply 200, [{
            uuid: 'cred-uuid'
            token: 'cred-token'
            endoSignature: 'chpYIsrXkwFXGJ+n/tPkS0UwIQlMr7F6xjP2QdFJP/sBwkDKokLyUgYW8ZYFbQn/RLriSv8Do7CmTBkoKofX5g=='
            endo:
              credentialsDeviceUuid: 'cred-uuid'
              encrypted: @encryptedSecrets
          }]

        @meshblu
          .post '/devices/cred-uuid/tokens'
          .set 'Authorization', "Basic #{serviceAuth}"
          .reply 201, '{"uuid": "cred-uuid", "token": "cred-token2"}'

        @updateCredentialsDevice = @meshblu
          .put '/v2/devices/cred-uuid'
          .set 'Authorization', "Basic #{credentialsDeviceAuth}"
          .send
            $set:
              endo:
                authorizedKey: 'pG7eYd4TYZOX2R5S73jo9aexPzldiNo4pw1wViDpYrAAGRMT6dY0jlbXbfHMz9y+El6AcXMZJEOxaeO1lITsYg=='
                idKey: 'Ula5075pW5J6pbIzhez3Be78UsyVApbXMXEPXmMwBAtVdtxdHoXNx+fI9nLV/pHZzlOI0RjhJmO+qQ3zAnKviw=='
                credentialsDeviceUuid: 'cred-uuid'
                version: '1.0.0'
                encrypted:
                  id:           'resource owner id'
                  username:     'resource owner username'
                  secrets:
                    credentials:
                      secret:       'resource owner secret'
                      refreshToken: 'resource owner refresh token'
                    credentialsDeviceToken: 'cred-token2'
              endoSignature: "i7OF2Kc6ReZ2EKpDRLgyt/VlyxilV7nes+36ib6zsqe6i90RkZ2IF9JRFhEcwWbt4/JYUpZcfr1YhODtGH769g=="
          .reply 204

        options =
          uri: '/auth/api/callback'
          baseUrl: "http://localhost:#{@serverPort}"
          followRedirect: false
          auth:
            username: 'some-uuid'
            password: 'some-token'
          qs:
            oauth_token: 'oauth_token'
            oauth_verifier: 'oauth_verifier'

        request.get options, (error, @response, @body) =>
          done error

      it 'should update the credentials device with the new resourceOwnerSecret and authorizedUuid', ->
        @updateCredentialsDevice.done()

      it 'should return a 301', ->
        expect(@response.statusCode).to.equal 301

      it 'should redirect to the userDeviceManagerUrl with the bearerToken and credentialsDeviceUrl', ->
        EXPECTED = 'http://manage-my.endo/?meshbluAuthBearer=c29tZS11dWlkOnNvbWUtdG9rZW4%3D&credentialsDeviceUrl=http%3A%2F%2Fthe-endo-url%2Fcredentials%2Fcred-uuid&appOctobluHost=http%3A%2F%2Fapp.octoblu.biz%2F'
        expect(@response.headers.location).to.equal EXPECTED

    describe 'when two credentials devices exist, but only one has an valid endoSignature', ->
      beforeEach (done) ->
        userAuth = new Buffer('some-uuid:some-token').toString 'base64'
        serviceAuth = new Buffer('peter:i-could-eat').toString 'base64'
        credentialsDeviceAuth = new Buffer('cred-uuid:cred-token2').toString 'base64'

        @apiStub.yields null, {
          id:       'resource owner id'
          username: 'resource owner username'
          secrets:
            credentials:
              secret:       'resource owner secret'
              refreshToken: 'resource owner refresh token'
        }

        @meshblu
          .post '/authenticate'
          .set 'Authorization', "Basic #{userAuth}"
          .reply 204

        @meshblu
          .post '/search/devices'
          .set 'Authorization', "Basic #{serviceAuth}"
          .send 'endo.idKey': 'Ula5075pW5J6pbIzhez3Be78UsyVApbXMXEPXmMwBAtVdtxdHoXNx+fI9nLV/pHZzlOI0RjhJmO+qQ3zAnKviw=='
          .reply 200, [{
            uuid: 'bad-cred-uuid'
            token: 'bad-cred-token'
            endoSignature: 'whatever'
            endo:
              credentialsDeviceUuid: 'bad-cred-uuid'
              encrypted: @encryptedSecrets
          }, {
            uuid: 'cred-uuid'
            token: 'cred-token'
            endoSignature: 'chpYIsrXkwFXGJ+n/tPkS0UwIQlMr7F6xjP2QdFJP/sBwkDKokLyUgYW8ZYFbQn/RLriSv8Do7CmTBkoKofX5g=='
            endo:
              credentialsDeviceUuid: 'cred-uuid'
              encrypted: @encryptedSecrets
          }]

        @meshblu
          .post '/devices/cred-uuid/tokens'
          .set 'Authorization', "Basic #{serviceAuth}"
          .reply 201, '{"uuid": "cred-uuid", "token": "cred-token2"}'

        @updateCredentialsDevice = @meshblu
          .put '/v2/devices/cred-uuid'
          .set 'Authorization', "Basic #{credentialsDeviceAuth}"
          .send
            $set:
              endo:
                authorizedKey: 'pG7eYd4TYZOX2R5S73jo9aexPzldiNo4pw1wViDpYrAAGRMT6dY0jlbXbfHMz9y+El6AcXMZJEOxaeO1lITsYg=='
                idKey: 'Ula5075pW5J6pbIzhez3Be78UsyVApbXMXEPXmMwBAtVdtxdHoXNx+fI9nLV/pHZzlOI0RjhJmO+qQ3zAnKviw=='
                credentialsDeviceUuid: 'cred-uuid'
                version: '1.0.0'
                encrypted:
                  id:       'resource owner id'
                  username: 'resource owner username'
                  secrets:
                    credentialsDeviceToken: 'cred-token2'
                    credentials:
                      secret:       'resource owner secret'
                      refreshToken: 'resource owner refresh token'
              endoSignature: "i7OF2Kc6ReZ2EKpDRLgyt/VlyxilV7nes+36ib6zsqe6i90RkZ2IF9JRFhEcwWbt4/JYUpZcfr1YhODtGH769g=="
          .reply 204

        options =
          uri: '/auth/api/callback'
          baseUrl: "http://localhost:#{@serverPort}"
          followRedirect: false
          auth:
            username: 'some-uuid'
            password: 'some-token'
          qs:
            oauth_token: 'oauth_token'
            oauth_verifier: 'oauth_verifier'

        request.get options, (error, @response, @body) =>
          done error

      it 'should update the credentials device with the new resourceOwnerSecret and authorizedUuid', ->
        @updateCredentialsDevice.done()

      it 'should return a 301', ->
        expect(@response.statusCode).to.equal 301

      it 'should redirect to the userDeviceManagerUrl with the bearerToken and credentialsDeviceUrl', ->
        EXPECTED = 'http://manage-my.endo/?meshbluAuthBearer=c29tZS11dWlkOnNvbWUtdG9rZW4%3D&credentialsDeviceUrl=http%3A%2F%2Fthe-endo-url%2Fcredentials%2Fcred-uuid&appOctobluHost=http%3A%2F%2Fapp.octoblu.biz%2F'
        expect(@response.headers.location).to.equal EXPECTED

    describe 'when two credentials devices exist with valid endoSignature, but one has a bad credentialsDeviceUrl', ->
      beforeEach (done) ->
        userAuth = new Buffer('some-uuid:some-token').toString 'base64'
        serviceAuth = new Buffer('peter:i-could-eat').toString 'base64'
        credentialsDeviceAuth = new Buffer('cred-uuid:cred-token2').toString 'base64'

        @apiStub.yields null, {
          id:       'resource owner id'
          username: 'resource owner username'
          secrets:
            credentials:
              secret:       'resource owner secret'
              refreshToken: 'resource owner refresh token'
        }

        @meshblu
          .post '/authenticate'
          .set 'Authorization', "Basic #{userAuth}"
          .reply 204

        @meshblu
          .post '/search/devices'
          .set 'Authorization', "Basic #{serviceAuth}"
          .send 'endo.idKey': 'Ula5075pW5J6pbIzhez3Be78UsyVApbXMXEPXmMwBAtVdtxdHoXNx+fI9nLV/pHZzlOI0RjhJmO+qQ3zAnKviw=='
          .reply 200, [{
            uuid: 'bad-cred-uuid'
            endoSignature: 'chpYIsrXkwFXGJ+n/tPkS0UwIQlMr7F6xjP2QdFJP/sBwkDKokLyUgYW8ZYFbQn/RLriSv8Do7CmTBkoKofX5g=='
            endo:
              credentialsDeviceUuid: 'cred-uuid'
              encrypted: @encryptedSecrets
          }, {
            uuid: 'cred-uuid'
            endoSignature: 'chpYIsrXkwFXGJ+n/tPkS0UwIQlMr7F6xjP2QdFJP/sBwkDKokLyUgYW8ZYFbQn/RLriSv8Do7CmTBkoKofX5g=='
            endo:
              credentialsDeviceUuid: 'cred-uuid'
              encrypted: @encryptedSecrets
          }]

        @meshblu
          .post '/devices/cred-uuid/tokens'
          .set 'Authorization', "Basic #{serviceAuth}"
          .reply 201, '{"uuid": "cred-uuid", "token": "cred-token2"}'

        @updateCredentialsDevice = @meshblu
          .put '/v2/devices/cred-uuid'
          .set 'Authorization', "Basic #{credentialsDeviceAuth}"
          .send
            $set:
              endo:
                authorizedKey: 'pG7eYd4TYZOX2R5S73jo9aexPzldiNo4pw1wViDpYrAAGRMT6dY0jlbXbfHMz9y+El6AcXMZJEOxaeO1lITsYg=='
                idKey: 'Ula5075pW5J6pbIzhez3Be78UsyVApbXMXEPXmMwBAtVdtxdHoXNx+fI9nLV/pHZzlOI0RjhJmO+qQ3zAnKviw=='
                credentialsDeviceUuid: 'cred-uuid'
                version: '1.0.0'
                encrypted:
                  id:       'resource owner id'
                  username: 'resource owner username'
                  secrets:
                    credentials:
                      secret:       'resource owner secret'
                      refreshToken: 'resource owner refresh token'
                    credentialsDeviceToken: "cred-token2"
              endoSignature: "i7OF2Kc6ReZ2EKpDRLgyt/VlyxilV7nes+36ib6zsqe6i90RkZ2IF9JRFhEcwWbt4/JYUpZcfr1YhODtGH769g=="
          .reply 204

        options =
          uri: '/auth/api/callback'
          baseUrl: "http://localhost:#{@serverPort}"
          followRedirect: false
          auth:
            username: 'some-uuid'
            password: 'some-token'
          qs:
            oauth_token: 'oauth_token'
            oauth_verifier: 'oauth_verifier'

        request.get options, (error, @response, @body) =>
          done error

      it 'should return a 301', ->
        expect(@response.statusCode).to.equal 301, JSON.stringify(@body)

      it 'should update the credentials device with the new resourceOwnerSecret and authorizedUuid', ->
        @updateCredentialsDevice.done()

      it 'should redirect to the userDeviceManagerUrl with the bearerToken and credentialsDeviceUrl', ->
        EXPECTED = 'http://manage-my.endo/?meshbluAuthBearer=c29tZS11dWlkOnNvbWUtdG9rZW4%3D&credentialsDeviceUrl=http%3A%2F%2Fthe-endo-url%2Fcredentials%2Fcred-uuid&appOctobluHost=http%3A%2F%2Fapp.octoblu.biz%2F'
        expect(@response.headers.location).to.equal EXPECTED

{beforeEach, describe, it} = global
{expect} = require 'chai'
path = require 'path'

MessageHandler = require '../src/message-handler'

describe.only 'MessageHandler', ->
  describe 'with an instance', ->
    beforeEach ->
      @sut = new MessageHandler
        jobsPath: path.join(__dirname, './fixtures/jobs')

    describe 'when called with a valid message for a valid job', ->
      beforeEach (done) ->
        message = {
          metadata:
            jobType: 'SayHello'
          data:
            uuid: 'some-uuid'
        }
        @sut.onMessage message, (error, @response) => done error

      it 'should yield a 204', ->
        expect(@response).to.deep.equal {
          metadata:
            code: 204
            status: 'No Content'
        }

    describe 'when called a message for a valid job that violates the schema', ->
      beforeEach (done) ->
        message = {
          metadata:
            jobType: 'SayHello'
          data:
            name: 'I have no UUID'
        }
        @sut.onMessage message, (error, @response) => done error

      it 'should yield a 422', ->
        expect(@response).to.deep.equal {
          metadata:
            code: 422
            status: 'Unprocessable Entity'
          data:
            errors: ['requires property "uuid"']
        }

    describe 'when called with a valid message for an dis-extant job', ->
      beforeEach (done) ->
        message = {
          metadata:
            jobType: 'DisExtant'
        }
        @sut.onMessage message, (error, @response) => done error

      it 'should yield a 404', ->
        expect(@response).to.deep.equal {
          metadata:
            code: 404
            status: 'Not Found'
        }

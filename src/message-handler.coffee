http = require 'http'
_    = require 'lodash'
path = require 'path'
glob = require 'glob'
{validate} = require 'jsonschema'

NOT_FOUND_RESPONSE = {metadata: {code: 404, status: http.STATUS_CODES[404]}}

class MessageHandler
  constructor: ({ @defaultJobType, @jobsPath }={})->
    throw new Error 'MessageHandler requires jobsPath' unless @jobsPath?
    @jobs = @_getJobs()

  onMessage: ({data, encrypted, metadata}, callback) =>
    job = @jobs[metadata?.jobType]
    job ?= @jobs[@defaultJobType] if @defaultJobType?
    return callback null, NOT_FOUND_RESPONSE unless job?

    schema = @_messageSchemaFromJob job, metadata?.jobType
    validation = validate {metadata, data}, schema

    return callback null, @_validationErrorsResponse(validation.errors) unless _.isEmpty validation.errors

    job.action {encrypted}, {data, metadata}, (error, response) =>
      return callback error if error?
      keys = _.keys _.omit response, ['data', 'metadata']
      console.error("Only `data` and `metadata` will be used, ignoring all other keys") unless _.isEmpty keys
      return callback null, _.pick(response, 'data', 'metadata')

  formSchema: (callback) =>
    callback null, @_formSchemaFromJobs @jobs

  messageSchema: (callback) =>
    callback null, @_messageSchemaFromJobs @jobs

  responseSchema: (callback) =>
    callback null, @_responseSchemaFromJobs @jobs

  _formSchemaFromJobs: (jobs) =>
    return {
      message: _.mapValues jobs, 'form'
    }

  _generateMessageMetadata: (jobType) =>
    return {
      type: 'object'
      required: ['jobType']
      properties:
        jobType:
          type: 'string'
          enum: [jobType]
          default: jobType
        respondTo: {}
    }

  _generateResponseMetadata: =>
    return {
      type: 'object'
      required: ['status', 'code']
      properties:
        status:
          type: 'string'
        code:
          type: 'integer'
    }

  _getJobs: =>
    dirnames = glob.sync path.join(@jobsPath, '/*/')
    jobs = {}
    _.each dirnames, (dir) =>
      key = _.upperFirst _.camelCase path.basename dir
      try
        jobs[key] = require dir
      catch error
        console.error error.stack

    return jobs

  _messageSchemaFromJob: (job, key) =>
    message = _.cloneDeep job.message
    message ?= {}
    _.set message, 'x-form-schema.angular', "message.#{key}.angular"
    _.set message, 'x-response-schema', "#{key}"
    _.set message, 'properties.metadata', @_generateMessageMetadata(key)
    message.required = _.union ['metadata'], message.required
    return message

  _messageSchemaFromJobs: (jobs) =>
    _.mapValues jobs, @_messageSchemaFromJob

  _responseSchemaFromJob: (job) =>
    response = _.cloneDeep job.response
    _.set response, 'properties.metadata', @_generateResponseMetadata()
    return response

  _responseSchemaFromJobs: (jobs) =>
    _.mapValues jobs, @_responseSchemaFromJob

  _validationErrorsResponse: (errors) =>
    return {
      metadata:
        code: 422
        status: http.STATUS_CODES[422]
      data:
        errors: _.map(errors, @_formatValidationError)
    }

  _formatValidationError: (error) =>
    return _.replace error.stack, /^instance\./, 'message.'

module.exports = MessageHandler

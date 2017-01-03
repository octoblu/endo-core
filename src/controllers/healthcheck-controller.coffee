_ = require 'lodash'

class HealthcheckController
  constructor: ({@healthcheckService})->
    throw new Error 'healthcheckService is required' unless @healthcheckService?
    throw new Error 'healthcheckService.healthcheck must be a function' unless _.isFunction @healthcheckService.healthcheck

  get: (req, res) =>
    @healthcheckService.healthcheck (error, response) =>
      return res.sendError error if error?
      return res.status(500).send(response) unless response.healthy
      return res.send response

module.exports = HealthcheckController

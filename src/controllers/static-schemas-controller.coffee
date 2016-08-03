fs    = require 'fs'
cson  = require 'cson'
_     = require 'lodash'
path  = require 'path'

class StaticSchemasController
  constructor: ({staticSchemasPath}) ->
    @staticSchemasPath = path.resolve staticSchemasPath unless _.isEmpty staticSchemasPath

  get: (request, response) =>
    return response.status(404).send error: 'This service has no static schemas configured' unless @staticSchemasPath

    {name} = request.params

    filePath = path.resolve(path.join(@staticSchemasPath, "#{name}.cson"))
    return response.status(400).send error: 'Invalid file path' unless @_validateFilePath filePath

    fs.readFile filePath, (error, csonData) =>
      return response.status(404).send error: 'Could not find a schema for that path' if error?

      cson.parse csonData, (error, data) =>
        return response.status(500).send error: 'Failed to parse schema' if error?
        return response.status(200).send data

  _validateFilePath: (filePath) =>
    _.startsWith filePath, @staticSchemasPath



module.exports = StaticSchemasController

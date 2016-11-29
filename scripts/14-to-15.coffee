MeshbluHttp   = require 'meshblu-http'
MeshbluConfig = require 'meshblu-config'
async         = require 'async'

meshbluConfig = new MeshbluConfig().toJSON()
meshblu       = new MeshbluHttp meshbluConfig

query =
  "meshblu.whitelists.configure.update": uuid: meshbluConfig.uuid

meshblu.search query, {projection: uuid: true}, (error, devices) =>
  console.error error if error?
  console.log JSON.stringify devices, null, 2

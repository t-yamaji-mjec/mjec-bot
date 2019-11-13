# Description:
#   IBM Cloud Object Storage アクセス用ライブラリ
#
# Notes:
#   共通ライブラリ
#

class CosDA
  constructor: (@robot) ->

  cosJson = process.env['COS_CONNECTION_JSON']
  config =
    accessKeyId: process.env['COS_ACCESS_KEY_ID'],
    secretAccessKey: process.env['COS_SECRET_ACCESS_KEY'],
    endpoint: process.env['COS_ENDPOINT'],
    apiKeyId: cosJson.apikey,
    ibmAuthEndpoint: 'https://iam.ng.bluemix.net/oidc/token',
    serviceInstanceId: cosJson.resource_instance_id

  objectStore = require('ibm-cos-sdk')
  cos = new objectStore.S3(config)

  doCreateObject : (bucket, path, body) ->
    console.log 'Creating object'
    return cos.putObject({
      Bucket: bucket,
      Key: path,
      Body: body
    }).promise()

  doGetObject : (bucket, path) ->
    console.log 'Getting object'
    return cos.getObject({
      Bucket: bucket
      Key: path}).promise()

  doDeleteObject : (bucket, path) ->
    console.log 'Deleting object'
    return cos.deleteObject({
      Bucket: bucket,
      Key: path
    }).promise()

  getBucketContents : (bucket) ->
    console.log  "Retrieving bucket contents from: #{bucket}"
    return cos.listObjects({
      Bucket: bucket
      }).promise()

module.exports = (robot) ->
  cos_da = new CosDA robot
  bucket = process.env['BUCKET_NAME']
  bucket = 'mjec-bot'
  path = 'test.txt'
  robot.hear /put test (.*)/i, (msg) ->
    cos_da.doCreateObject(bucket, path, body=msg.match[1])
  robot.hear /get test/i, (msg) ->
    cos_da.doGetObject(bucket, path).then(
      (data) -> msg.send '取得内容:' + Buffer.from(data.Body).toString() if data isnt null)
  robot.hear /del test/i, (msg) ->
    cos_da.doDeleteObject(bucket, path)
  robot.hear /list test/i, (msg) ->
    cos_da.getBucketContents(bucket).then(
      (data) -> msg.send contents.Key + ", " for contents in data.Contents if data isnt null and data isnt null)
  module.exports = CosDA

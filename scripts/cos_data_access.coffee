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

  doCreateBucket : (bucket, location) ->
    console.log('Creating bucket');
    return cos.createBucket({
        Bucket: bucket,
        CreateBucketConfiguration: {
          LocationConstraint: location
        },
    }).promise();

  doCreateObject : (bucket, path, body) ->
    console.log 'Creating object'
    return cos.putObject({
      Bucket: bucket,
      Key: path,
      Body: body
    }).promise()

  doGetObject : (bucket, path) ->
    console.log 'Getting object'
    fs = require('fs')
    streams = require('memory-streams')
    dest = new streams.WritableStream()
    return cos.getObject({
      Bucket: bucket,
      Key: path
    }).createReadStream().pipe(dest)

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
  bucket = 'mjec-hubot'
  path = 'test.txt'
  #robot.hear /bucket test (.*) (.*)/i, (msg) ->
  #  cos_da.doCreateBucket(bucket=msg.match[1], location=msg.match[2])
  robot.hear /put test (.*)/i, (msg) ->
    cos_da.doCreateObject(bucket, path, body=msg.match[1])
  robot.hear /get test/i, (msg) ->
    msg.send '取得内容:' + cos_da.doGetObject(bucket, path).toString()
  robot.hear /del test/i, (msg) ->
    cos_da.doDeleteObject(bucket, path)
  robot.hear /list test/i, (msg) ->
    console.log cos_da.getBucketContents(bucket)
  module.exports = CosDA

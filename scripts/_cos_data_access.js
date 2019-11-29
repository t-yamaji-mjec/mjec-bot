// Description:
//   IBM Cloud Object Storage アクセス用ライブラリ.
// Notes:
//   共通ライブラリ.

var CosDA
CosDA = (function() {
  function CosDA(robot1) {
    this.robot = robot1;
  }

  var cosJson = process.env['COS_CONNECTION_JSON'];
  var config = {
    accessKeyId: process.env['COS_ACCESS_KEY_ID'],
    secretAccessKey: process.env['COS_SECRET_ACCESS_KEY'],
    endpoint: process.env['COS_ENDPOINT'],
    apiKeyId: cosJson.apikey,
    ibmAuthEndpoint: 'https://iam.ng.bluemix.net/oidc/token',
    serviceInstanceId: cosJson.resource_instance_id
  };

  var objectStore = require('ibm-cos-sdk');
  var cos = new objectStore.S3(config);

  CosDA.doCreateObject = function(bucket, path, body) {
    console.log('Creating object');
    return cos.putObject({
      Bucket: bucket,
      Key: path,
      Body: body
    }).promise();
  };

  CosDA.doGetObject = function(bucket, path) {
    console.log('Getting object');
    return cos.getObject({
      Bucket: bucket,
      Key: path
    }).promise();
  };

  CosDA.doDeleteObject = function(bucket, path) {
    console.log('Deleting object');
    return cos.deleteObject({
      Bucket: bucket,
      Key: path
    }).promise();
  };

  CosDA.doListObjects = function(bucket) {
    console.log('Listing object');
    return cos.listObjects({
      Bucket: bucket
    }).promise();
  };

  CosDA.doCopyObject = function(bucket, copyPath, pastePath) {
    console.log('Copying object');
    return cos.copyObject({
      Bucket: bucket,
      CopySource: copyPath,
      Key: pastePath
    }).promise();
  };

  return CosDA;
})();

module.exports = function(robot) {
  var cos_da = new CosDA(robot);
  var bucket = process.env['BUCKET_NAME'];
  var path = 'test.txt';
/* テスト用
  robot.hear(/put test (.*)/i, function(msg) {
    CosDA.doCreateObject(bucket, path, body=msg.match[1]);
  });
  robot.hear(/get test/i, function(msg) {
    CosDA.doGetObject(bucket, path).then((data) => {
      msg.send('body:' + Buffer.from(data.Body).toString())
    });
  });
  robot.hear(/del test/i, function(msg) {
    CosDA.doDeleteObject(bucket, path);
  });
  robot.hear(/copy test/i, function(msg) {
    CosDA.doCopyObject(bucket, bucket + "/" + path, "copy/test.txt");
  });
  robot.hear(/list test/i, function(msg) {
    CosDA.doListObjects(bucket).then((data) => {
      if (data != null && data.Contents != null) {
        for (var i = 0; i < data.Contents.length; i++) {
          var itemKey = data.Contents[i].Key;
          var itemSize = data.Contents[i].Size;
          console.log(`Item: ${itemKey} (${itemSize} bytes).`)
        }
      }
    });
  });
*/
  return module.exports = CosDA;
};

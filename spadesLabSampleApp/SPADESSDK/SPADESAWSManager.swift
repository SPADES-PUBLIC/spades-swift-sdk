//
//  SPADESAWSManager.swift
//  spadesLabSampleApp
//
//  Created by Stanis Laus Billy on 2/29/16.
//  Copyright © 2016 QMEDIC. All rights reserved.
//

import Foundation
import AWSS3
import AWSSQS
import SwiftyJSON

class SPADESAWSInfo {
    var accessKeyId:String = ""
    var secretAccessKey:String = ""
    var s3BucketName:String = ""
    var sqsQueueName:String = ""
    var spadesEnvironment:SPADESEnvironmentType = .UNKNOWN
    var regionType:AWSRegionType = .Unknown
    
    func isValid() -> Bool {
        return !accessKeyId.isEmpty && !secretAccessKey.isEmpty && !s3BucketName.isEmpty && !sqsQueueName.isEmpty && spadesEnvironment != .UNKNOWN && regionType != .Unknown
    }
}

class SPADESSQSInfo {
    var sensorId:String = ""
    var sensorType:String = ""
    var studyId:String = ""
    var mHealthType:String = ""
    var filename:String = ""
    var fileKey:String = ""
    var bytesTransferred:Int64 = 0
    var fileGuid:String = ""
    var participantCode:String = ""
}

class SPADESAWSManager {
    
    static let MHEALTH_UPLOAD_FILE_ACTION = "MHEALTH_UPLOAD_FILE"
    static let SQS_MESSAGE_ATTRIBUTE_KEY = "QUEUE_ACTION"
    static let SQS_ORIGIN = "SDK_IOS"
    
    class func CreateSQSJson(info:SPADESSQSInfo) -> JSON {
        var metadataJson = JSON([:])
        metadataJson["fileFormat"].string = "MHEALTH"
        metadataJson["serialNumber"].string = info.sensorId
        metadataJson["sensorType"].string = info.sensorType
        metadataJson["studyId"].int = Int(info.studyId)
        metadataJson["mHealthType"].string = info.mHealthType
        
        var json = JSON([:])
        json["sensorId"].string = info.sensorId
        json["filename"].string = info.filename
        json["s3KeyPath"].string = info.fileKey
        json["fileSizeInBytes"].int64 = info.bytesTransferred
        json["sensorMetaData"] = metadataJson
        json["transactionId"].string = info.fileGuid
        json["participantCode"].string = info.participantCode
        json["origin"].string = SQS_ORIGIN
        
        return json
    }
    
    class func SendMessageToSQS(message:String, queueName:String) {
        let queueName = queueName
        let sqs = AWSSQS.defaultSQS()
        let getQueueUrlRequest = AWSSQSGetQueueUrlRequest()
        getQueueUrlRequest.queueName = queueName
        sqs.getQueueUrl(getQueueUrlRequest).continueWithBlock { (task) -> AnyObject! in
            print("Attempting to get QUEUE URL...")
            if let error = task.error {
                print("Error. \(error)")
            }
            if let exception = task.exception {
                print("Exception. \(exception)")
            }
            if task.result != nil {
                //print("Success. \(task.result)")
                if let queueUrl = task.result!.queueUrl {
                    print("Got SQS URL: \(queueUrl!)")
                    
                    // Try to send a message
                    let sendMsgRequest = AWSSQSSendMessageRequest()
                    sendMsgRequest.queueUrl = queueUrl
                    sendMsgRequest.messageBody = message
                    // Add message attributes to specify intended action
                    let msgAttribute = AWSSQSMessageAttributeValue()
                    msgAttribute.dataType = "String"
                    msgAttribute.stringValue = MHEALTH_UPLOAD_FILE_ACTION
                    sendMsgRequest.messageAttributes = [:]
                    sendMsgRequest.messageAttributes![SQS_MESSAGE_ATTRIBUTE_KEY] = msgAttribute
                    sqs.sendMessage(sendMsgRequest).continueWithBlock { (task) -> AnyObject! in
                        print("Attempting to send a QUEUE message...")
                        if let error = task.error {
                            print("Error. \(error)")
                        }
                        if let exception = task.exception {
                            print("Exception. \(exception)")
                        }
                        if task.result != nil {
                            //print("Success. \(task.result)")
                            print("Success!")
                        }
                        return nil
                    }
                } else {
                    print("No URL found for \(queueName)!")
                }
            }
            return nil
        }
    }
    
    class func PushFileToS3(fileFullPath:String, targetBucket:String, fileKey:String, removeOriginal: Bool, onCompleted:(Bool,Int64) -> Void) {
        let fileUrl = NSURL.fileURLWithPath(fileFullPath)
        let fileMgr = NSFileManager.defaultManager()
        
        // Check if file exists first
        if !fileMgr.fileExistsAtPath(fileFullPath) {
            print("\(fileFullPath) doesn't exist!")
            onCompleted(false, 0)
            return
        }
        
        // Upload the file to S3
        let uploadRequest = AWSS3TransferManagerUploadRequest()
        uploadRequest.body = fileUrl
        uploadRequest.key = fileKey
        uploadRequest.bucket = targetBucket
        uploadRequest.contentType = "text/csv"
        uploadRequest.contentEncoding = "gzip"
        uploadRequest.serverSideEncryption = AWSS3ServerSideEncryption.AES256
        
        // Track upload progress
        var bytesTransferred:Int64 = 0
        uploadRequest.uploadProgress = { (bytesSent:Int64, totalBytesSent:Int64, totalBytesExpectedToSend:Int64) -> Void in
            dispatch_sync(dispatch_get_main_queue(), { () -> Void in
                //print(bytesSent, totalBytesSent, totalBytesExpectedToSend)
                bytesTransferred = totalBytesSent
            })
        }
        
        let transferMgr = AWSS3TransferManager.defaultS3TransferManager()
        transferMgr.upload(uploadRequest).continueWithBlock { (task) -> AnyObject! in
            print("Upload result: \(fileKey)")
            if let error = task.error {
                if error.domain == AWSS3TransferManagerErrorDomain as String {
                    if let errorCode = AWSS3TransferManagerErrorType(rawValue: error.code) {
                        switch(errorCode) {
                        case .Cancelled, .Paused:
                            UntrackUploadFile(fileFullPath, output: "Cancelled or Paused. \(errorCode). \(error)")
                            onCompleted(false, bytesTransferred)
                            break
                        default:
                            UntrackUploadFile(fileFullPath, output: "Failed. \(error)")
                            onCompleted(false, bytesTransferred)
                            break;
                        }
                    } else {
                        UntrackUploadFile(fileFullPath, output: "Failed. \(error)")
                        onCompleted(false, bytesTransferred)
                    }
                } else {
                    UntrackUploadFile(fileFullPath, output: "Failed. \(error)")
                    onCompleted(false, bytesTransferred)
                }
            }
            
            if let exception = task.exception {
                UntrackUploadFile(fileFullPath, output: "Failed. \(exception)")
                onCompleted(false, bytesTransferred)
            }
            
            if task.result != nil {
                if let eTag = task.result?.ETag! {
                    // Get MD5 of file content and compare against the eTag
                    let gzData = NSData(contentsOfFile: fileFullPath)
                    let gzContentMD5 = "\"\(MD5ofNSData(gzData!))\""
                    if eTag == gzContentMD5 {
                        UntrackUploadFile(fileFullPath, output: "Succeeded. \(fileFullPath) uploaded!")
                        onCompleted(true, bytesTransferred)
                        if removeOriginal {
                            do {
                                try fileMgr.removeItemAtPath(fileFullPath)
                            } catch let error as NSError {
                                UntrackUploadFile(fileFullPath, output: "Failed to delete \(fileFullPath) after upload. \(error.localizedDescription)")
                            }
                        }
                    } else {
                        UntrackUploadFile(fileFullPath, output: "Failed. File \(fileFullPath) corrupted during transfer...")
                        onCompleted(false, bytesTransferred)
                    }
                }
            }
            return nil
        }
    }
    
    private class func UntrackUploadFile(fileFullPath: String, output:String) {
        print(output)
    }
    
    private class func MD5ofNSData(data:NSData) -> String {
        var digest = [UInt8](count: Int(CC_MD5_DIGEST_LENGTH), repeatedValue: 0)
        CC_MD5(data.bytes, CC_LONG(data.length), &digest)
        
        var digestHex = ""
        for index in 0..<Int(CC_MD5_DIGEST_LENGTH) {
            digestHex += String(format: "%02x", digest[index])
        }
        return digestHex
    }
}
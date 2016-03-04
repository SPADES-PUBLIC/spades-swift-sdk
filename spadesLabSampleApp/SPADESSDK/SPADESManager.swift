//
//  QSPLManager.swift
//  spadesLabSampleApp
//
//  Created by Stanis Laus Billy on 2/26/16.
//  Copyright © 2016 QMEDIC. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

// The strings correspond to the "response" returned from SPADES
enum SPADESResponse:String {
    case SUCCESS = "OK"
    case APP_NOT_AUTHENTICATED = "APP_NOT_AUTHENTICATED"
    case CREDENTIALS_ERROR = "CREDENTIALS_ERROR"
    case FAILED = "FAILED"
    case FILE_NOT_EXIST = "FILE_NOT_EXIST"
    case GCM_NOT_REGISTERED = "GCM_NOT_REGISTERED"
    case INVALID_API_URL = "INVALID_API_URL"
    case INVALID_AWS_INFO = "INVALID_AWS_INFO"
    case INVALID_MHEALTH_FILE = "INVALID_MHEALTH_FILE"
    case INVALID_SENSORS = "INVALID_SENSORS"
    case INVALID_PARAMS = "INVALID_REQUEST_PARAMS"
    case PARTICIPANT_NOT_FOUND = "PARTICIPANT_NOT_FOUND"
    case SERVER_RESPONSE_ERROR = "SERVER_RESPONSE_ERROR"
    case UNAUTHORIZED = "UNAUTHORIZED"
    case UNKNOWN_ERROR = "UNKNOWN_ERROR"
}

// Metadata type used in RESTful calls to SPADES (eg. protocol)
enum SPADESMetadataType:String {
    case PARTICIPANT_ID = "participantCode"
    case SENSOR_SERIAL_NUMBER = "sensorSerialNumber"
}

// SPADES server environment type
enum SPADESEnvironmentType:String {
    case DEVELOPMENT = "development"
    case PRODUCTION = "production"
    case UNKNOWN = "unknown"
}

struct SPADESMobileUser {
    var username:String
    var password:String
    var participantId:String
    var phoneNumber:String
    var installToken:String
}

class SPADESManager {
    
    static var SPADES_URL = ""
    
    // MARK: HELPER FUNCTIONS

    // Create a sensor object that can be registered with SPADES
    class func CreateSensorObjectForSPADES(sensorType:MHealthSensor, participantId: String, serialNumber: String) -> [String:AnyObject] {
        var spadesSensorType = "NOTSUPPORTED"
        switch sensorType {
        case .ANNOTATION:
            spadesSensorType = "ANNOTATION"
            break
        case .GPS:
            spadesSensorType = "GPS"
            break
        case .PROMIS:
            spadesSensorType = "PROMISASSESSMENT"
            break
        case .STEPS:
            spadesSensorType = "STEPCOUNT"
            break
        }
        let sensor:[String:AnyObject] = [
            "participantCode": participantId,
            "serialNumber": "\(serialNumber)-\(sensorType.rawValue)",
            "startDate": Int(NSDate().timeIntervalSince1970),
            "sensorType": spadesSensorType,
            "sensorName": sensorType.rawValue
        ]
        return sensor
    }
    
    // Parse the SPADES token to obtain the device's study ID
    class func GetStudyIdFromToken(token:String) -> String? {
        if token.isEmpty {
            return nil
        }
        
        if let tokenData = NSData(base64EncodedString: token, options: NSDataBase64DecodingOptions(rawValue: 0)) {
            if let studyId = NSString(data: tokenData, encoding: NSUTF8StringEncoding) as? String {
                return studyId
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    
    // MARK: SPADES-RELATED FUNCTIONS
    
    // Authenticate that the app is installed in a valid participant's phone in a SPADES study
    class func AuthenticateAppInstallation(phoneNumber:String, installToken:String, onCompleted:(SPADESResponse, SPADESMobileUser?) -> Void) {
        print("Authenticating app installation with SPADES...")
        var mobileUser: SPADESMobileUser?
        
        if SPADES_URL.isEmpty {
            onCompleted(SPADESResponse.INVALID_API_URL, nil)
            return
        }
        
        let url = "\(SPADES_URL)/mobile/auth?number=\(phoneNumber)&token=\(installToken)"
        Alamofire.request(.GET, url, parameters: [:]).responseJSON {
            response in
            var authResponse = SPADESResponse.FAILED
            if response.result.isSuccess {
                let json = JSON(data: response.data!)
                let uname = json["username"].string
                let pass = json["password"].string
                let pId = json["participantId"].string
                let result = json["result"].string
                if uname != nil && pass != nil && pId != nil {
                    mobileUser = SPADESMobileUser(username: uname!, password: pass!, participantId: pId!, phoneNumber: phoneNumber, installToken: installToken)
                } else {
                    print("Unable to create mobile user object!")
                }
                if result != nil {
                    authResponse = SPADESResponse.init(rawValue: result!)!
                }
            }
            onCompleted(authResponse, mobileUser)
        } // END HTTP Request
    }
    
    // Login as a mobile user
    class func LoginUser(username:String, password:String, onCompleted:(SPADESResponse, String?) -> Void) {
        print("Logging in user with SPADES...")
        
        if SPADES_URL.isEmpty {
            onCompleted(SPADESResponse.INVALID_API_URL, nil)
            return
        }
        
        if username.isEmpty || password.isEmpty {
            onCompleted(SPADESResponse.APP_NOT_AUTHENTICATED, nil)
            return
        }
        
        // Prepare request arguments
        let params:[String:AnyObject] = [
            "username": username,
            "password": password
        ]
        let headers = [
            "Content-Type": "application/json"
        ]
        let paramEncoding = ParameterEncoding.JSON
        
        // Fire the request
        let url = "\(SPADES_URL)/api/login"
        Alamofire.request(.POST, url, parameters: params, encoding: paramEncoding, headers: headers).responseJSON {
            response in
            if !response.result.isSuccess {
                onCompleted(SPADESResponse.FAILED, nil)
            } else {
                let json = JSON(data: response.data!)
                let accessToken = json["access_token"].string
                if accessToken == nil {
                    onCompleted(SPADESResponse.CREDENTIALS_ERROR, nil)
                } else {
                    onCompleted(SPADESResponse.SUCCESS, accessToken)
                }
            }
        } // END HTTP Request
    }
    
    // Register iOS-compatible sensors with SPADES
    class func RegisterSensors(mobileUser:SPADESMobileUser, accessToken:String, onCompleted:SPADESResponse -> Void) {
        let studyId = GetStudyIdFromToken(mobileUser.installToken)
        let participantId = mobileUser.participantId
        let appId = mobileUser.phoneNumber
        print("Registering sensors with SPADES...")
        
        if SPADES_URL.isEmpty {
            onCompleted(SPADESResponse.INVALID_API_URL)
            return
        }
        
        if accessToken.isEmpty {
            onCompleted(SPADESResponse.UNAUTHORIZED)
            return
        }
        
        if studyId == nil || appId.isEmpty || participantId.isEmpty {
            onCompleted(SPADESResponse.APP_NOT_AUTHENTICATED)
            return
        }
        
        // Prepare request arguments
        let stepsSensor = CreateSensorObjectForSPADES(MHealthSensor.STEPS, participantId: participantId, serialNumber: appId)
        let promisSensor = CreateSensorObjectForSPADES(MHealthSensor.PROMIS, participantId: participantId, serialNumber: appId)
        let annotationSensor = CreateSensorObjectForSPADES(MHealthSensor.ANNOTATION, participantId: participantId, serialNumber: appId)
        let gpsSensor = CreateSensorObjectForSPADES(MHealthSensor.GPS, participantId: participantId, serialNumber: appId)
        var sensors:[[String:AnyObject]] = []
        sensors.append(stepsSensor)
        sensors.append(promisSensor)
        sensors.append(annotationSensor)
        sensors.append(gpsSensor)
        var params:[String:AnyObject] = [:]
        params["id"] = Int(studyId!)
        params["uploadSensors"] = sensors
        let headers = [
            "Content-Type": "application/json",
            "X-Auth-Token": accessToken
        ]
        let paramEncoding = ParameterEncoding.JSON
        
        // Fire the request
        let url = "\(SPADES_URL)/api/studies/\(studyId!)/addSensors"
        Alamofire.request(.PUT, url, parameters: params, encoding: paramEncoding, headers: headers).responseJSON {
            response in
            if !response.result.isSuccess {
                onCompleted(SPADESResponse.FAILED)
            } else {
                let json = JSON(data: response.data!)
                if json["errors"].count > 0 { // Make sure there were no errors
                    onCompleted(SPADESResponse.INVALID_SENSORS)
                } else if json["records"].count != sensors.count { // Make sure all sensors registered successfully
                    onCompleted(SPADESResponse.UNKNOWN_ERROR)
                } else {
                    onCompleted(SPADESResponse.SUCCESS)
                }
            }
        } // END HTTP Request
    }
    
    // Register push notification key with SPADES (GCM-only!)
    class func RegisterDeviceForPushNotifications(mobileUser:SPADESMobileUser, accessToken:String, pushKey:String, onCompleted:SPADESResponse -> Void) {
        let studyId = GetStudyIdFromToken(mobileUser.installToken)
        let appId = mobileUser.phoneNumber
        print("Registering device for push notifications with SPADES...")
        
        if SPADES_URL.isEmpty {
            onCompleted(SPADESResponse.INVALID_API_URL)
            return
        }
        
        if accessToken.isEmpty {
            onCompleted(SPADESResponse.UNAUTHORIZED)
            return
        }
        
        if studyId == nil || appId.isEmpty {
            onCompleted(SPADESResponse.APP_NOT_AUTHENTICATED)
            return
        }
        
        if pushKey.isEmpty {
            onCompleted(SPADESResponse.GCM_NOT_REGISTERED)
            return
        }
        
        // Prepare request arguments
        let headers = [
            "Content-Type": "application/json",
            "X-Auth-Token": accessToken
        ]
        
        // Fire the request
        let url = "\(SPADES_URL)/api/sensor/register?serialNumber=\(appId)&pushNotificationKey=\(pushKey)"
        Alamofire.request(.GET, url,  headers: headers).responseJSON {
            response in
            if !response.result.isSuccess {
                onCompleted(SPADESResponse.FAILED)
            } else {
                let json = JSON(data: response.data!)
                let rStudyId = json["id"].int
                let rSerialNumber = json["serialNumber"].string
                let rSensorType = json["sensorType"].string
                let rPushKey = json["pushNotificationKey"].string
                if rStudyId == nil || rSerialNumber == nil || rSensorType == nil || rPushKey == nil {
                    onCompleted(SPADESResponse.SERVER_RESPONSE_ERROR)
                } else {
                    let studyIdOK = rStudyId! == Int(studyId!)
                    let appIdOK = rSerialNumber! == appId
                    let deviceTypeOK = rSensorType! == "IPHONE"
                    let pushKeyOK = rPushKey! == pushKey
                    if !studyIdOK || !appIdOK || !deviceTypeOK || !pushKeyOK {
                        onCompleted(SPADESResponse.FAILED)
                    } else {
                        onCompleted(SPADESResponse.SUCCESS)
                    }
                }
            }
        } // END HTTP Request
    }
    
    // Query SPADES for a protocol or a set of protocols.
    // To query for a set of protocols for target phone, use the PARTICIPANT_ID metadata with protocol ID = -1
    // To query for a specific protocol (known ID), use the SENSOR_SERIAL_NUMBER metadata with the known protocol ID
    class func FetchProtocol(mobileUser:SPADESMobileUser, accessToken:String, protocolId:Int, metadataType:SPADESMetadataType, onCompleted:(SPADESResponse, JSON?) -> Void) {
        let studyId = GetStudyIdFromToken(mobileUser.installToken)
        let appId = mobileUser.phoneNumber
        let participantId = mobileUser.participantId
        print("Fetching protocol(s) from SPADES...")
        
        if SPADES_URL.isEmpty {
            onCompleted(SPADESResponse.INVALID_API_URL, nil)
            return
        }
        
        if accessToken.isEmpty {
            onCompleted(SPADESResponse.UNAUTHORIZED, nil)
            return
        }
        
        if studyId == nil || (metadataType == .SENSOR_SERIAL_NUMBER && appId.isEmpty) || (metadataType == .PARTICIPANT_ID && participantId.isEmpty)  {
            onCompleted(SPADESResponse.APP_NOT_AUTHENTICATED, nil)
            return
        }
        
        // Prepare request arguments
        let headers = [
            "Content-Type": "application/json",
            "X-Auth-Token": accessToken
        ]
        
        // Prepare URL params based on the metadata type
        var param = "participantCode"
        switch metadataType {
        case .PARTICIPANT_ID:
            param = "participantCode"
            break
        case .SENSOR_SERIAL_NUMBER:
            param = "sensorSerialNumber"
            break
        }
        
        // Construct URL based on function parameters
        var url = "\(SPADES_URL)/api/studies/\(studyId!)"
        if protocolId > -1 {
            url += "/protocols/\(protocolId)?version=1.0&format=mobile&\(param)=\(participantId)"
        } else {
            url += "/participants/-1/protocols?version=1.0&\(param)=\(appId)"
        }
        
        // Fire the request
        Alamofire.request(.GET, url,  headers: headers).responseJSON {
            response in
            if !response.result.isSuccess {
                onCompleted(SPADESResponse.FAILED, nil)
            } else {
                let json = JSON(data: response.data!)
                onCompleted(SPADESResponse.SUCCESS, json)
            }
        } // END HTTP Request
    }
    
    // Upload a file to SPADES with the provided AWS information
    class func UploadFile(mobileUser:SPADESMobileUser, awsInfo:SPADESAWSInfo, fileFullPath:String, onCompleted: (SPADESResponse, String?) -> Void) {
        let studyId = GetStudyIdFromToken(mobileUser.installToken)
        let participantId = mobileUser.participantId
        print("Attempting to upload to SPADES: \(fileFullPath)")
        
        if studyId == nil || participantId.isEmpty {
            onCompleted(SPADESResponse.APP_NOT_AUTHENTICATED, nil)
            return
        }
        
        if !awsInfo.isValid() {
            onCompleted(SPADESResponse.INVALID_AWS_INFO, nil)
            return
        }
        
        let filename = fileFullPath.characters.split("/").map(String.init).last
        if filename == nil || !MHealthUtils.IsValidMHealthFilename(filename!) {
            onCompleted(SPADESResponse.INVALID_MHEALTH_FILE, nil)
            return
        }
        
        if !NSFileManager.defaultManager().fileExistsAtPath(fileFullPath) {
            onCompleted(SPADESResponse.FILE_NOT_EXIST, nil)
        }
        
        // Set up AWS credentials
        let credentialsProvider = AWSStaticCredentialsProvider(accessKey: awsInfo.accessKeyId, secretKey: awsInfo.secretAccessKey)
        let config = AWSServiceConfiguration(region: awsInfo.regionType, credentialsProvider: credentialsProvider)
        AWSServiceManager.defaultServiceManager().defaultServiceConfiguration = config
        
        // Upload the file to S3 and send a message to SQS to process the file
        let s3Prefix = "\(awsInfo.spadesEnvironment.rawValue)/UPLOADS/\(studyId!)"
        let fileKey = "\(s3Prefix)/\(filename!)"
        let fileGuid = NSUUID().UUIDString
        SPADESAWSManager.PushFileToS3(fileFullPath, targetBucket: awsInfo.s3BucketName, fileKey: fileKey, removeOriginal: false) {
            (succeeded, bytesTransferred) in
            if !succeeded {
                onCompleted(SPADESResponse.FAILED, nil)
            } else {
                let sqsInfo = SPADESSQSInfo()
                sqsInfo.sensorId = MHealthUtils.ParseSerialNumber(filename!)
                sqsInfo.sensorType = MHealthUtils.ParseDataAndSensorInfo(filename!)
                sqsInfo.studyId = studyId!
                sqsInfo.mHealthType = MHealthUtils.ParseMHealthType(filename!)
                sqsInfo.filename = filename!
                sqsInfo.fileKey = fileKey
                sqsInfo.bytesTransferred = bytesTransferred
                sqsInfo.fileGuid = fileGuid
                sqsInfo.participantCode = participantId
                let sqsJson = SPADESAWSManager.CreateSQSJson(sqsInfo)
                SPADESAWSManager.SendMessageToSQS(sqsJson.rawString()!, queueName: awsInfo.sqsQueueName)
                onCompleted(SPADESResponse.SUCCESS, fileGuid)
            }
        } // END HTTP Request
    }
    
}

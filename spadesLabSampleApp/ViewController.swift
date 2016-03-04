//
//  ViewController.swift
//  spadesLabSampleApp
//
//  Created by Stanis Laus Billy on 2/26/16.
//  Copyright © 2016 QMEDIC. All rights reserved.
//


// NOTE: This is a sample application that is run-able as is, with a few
//       pre-requisites below.
// 1. In terminal, go to the root directory of the project and run "pod install".
// 2. Go to the viewDidLoad() function and look for "FILL IN!" comments and add
//    your own information. The API usage examples are in "TestButtonClicked()"
//    function in this file.
// 3. Build and run. Once the app is running, press "Click Me" to go through
//    all of the API sample usages. Also see console outputs for return values.


// INTEGRATION:
// To integrate the SDK into your Swift-based project, copy all files under
// "SPADESSDK" and add the import lines in "SupportingFiles/spadesLabSampleApp
// -Bridging-Header.h" to your own app's Objective-C bridging header file.

import UIKit

enum AppState: Int {
    case UNKNOWN = 0
    case INSTALLATION_VERIFIED
    case LOGGED_IN
    case SENSORS_REGISTERED
    case PUSHKEY_REGISTERED
    case PROTOCOL_ALL_FETCHED
    case PROTOCOL_ONE_FETCHED
    case FILE_UPLOADED
}

class ViewController: UIViewController {

    // MARK: Properties
    @IBOutlet weak var testButton: UIButton!
    @IBOutlet weak var installationVerifiedText: UITextView!
    @IBOutlet weak var loggedInText: UITextView!
    @IBOutlet weak var sensorsRegisteredText: UITextView!
    @IBOutlet weak var pushKeyRegisteredText: UITextView!
    @IBOutlet weak var allProtocolFetchedText: UITextView!
    @IBOutlet weak var oneProtocolFetchedText: UITextView!
    @IBOutlet weak var fileUploadedText: UITextView!
    @IBOutlet weak var allDoneText: UITextView!
    
    // MARK: Mock app state
    var appState: AppState!
    
    // MARK: Mock user inputs
    var phoneNumber: String = ""
    var appInstallToken: String = ""
    
    // MARK: Mock saved user information
    var mobileUser: SPADESMobileUser?
    var accessToken: String = ""
    var awsInfo: SPADESAWSInfo!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize app state
        self.appState = AppState.UNKNOWN
        
        // Set user inputs
        self.phoneNumber = "" // FILL IN!
        self.appInstallToken = "" // FILL IN!
        
        // Set the URL of the target SPADES API
        SPADESManager.SPADES_URL = "" // FILL IN!
        self.awsInfo = SPADESAWSInfo()
        self.awsInfo.accessKeyId = "" // FILL IN!
        self.awsInfo.secretAccessKey = "" // FILL IN!
        self.awsInfo.spadesEnvironment = SPADESEnvironmentType.DEVELOPMENT // or .PRODUCTION
        self.awsInfo.s3BucketName = "" // FILL IN!
        self.awsInfo.sqsQueueName = "" // FILL IN!
        self.awsInfo.regionType = AWSRegionType.USEast1 // FILL IN!
    }

    // MARK: Actions
    @IBAction func testButtonClicked(sender: UIButton) {
        self.testButton.enabled = false
        
        switch self.appState! {
        case .UNKNOWN:
            // Step 1: Authenticate the app installation
            SPADESManager.AuthenticateAppInstallation(self.phoneNumber, installToken: self.appInstallToken) {
                (response, mobileUser) in
                print(response)
                if response == .SUCCESS {
                    self.appState = .INSTALLATION_VERIFIED
                    self.installationVerifiedText.text = "App installation verified..."
                    self.mobileUser = mobileUser
                }
                self.testButton.enabled = true
            }
            break
        case .INSTALLATION_VERIFIED:
            // Step 2: Authenticate the user
            let username = mobileUser?.username
            let password = mobileUser?.password
            SPADESManager.LoginUser(username!, password: password!) {
                (response, accessToken) in
                print(response)
                if response == .SUCCESS {
                    self.appState = .LOGGED_IN
                    self.loggedInText.text = "User logged in..."
                    self.accessToken = accessToken!
                }
                self.testButton.enabled = true
            }
            break
        case .LOGGED_IN:
            // Step 3: Register device sensors
            SPADESManager.RegisterSensors(mobileUser!, accessToken: self.accessToken) {
                (response) in
                print(response)
                if response == .SUCCESS {
                    self.appState = .SENSORS_REGISTERED
                    self.sensorsRegisteredText.text = "Sensors registered..."
                }
                self.testButton.enabled = true
            }
            break
        case .SENSORS_REGISTERED:
            // Step 4: OPTIONAL! Register push notification key
            SPADESManager.RegisterDeviceForPushNotifications(mobileUser!, accessToken: self.accessToken, pushKey: "testPushKey") {
                (response) in
                print(response)
                if response == .SUCCESS {
                    self.appState = .PUSHKEY_REGISTERED
                    self.pushKeyRegisteredText.text = "(Optional) Push notification key registered..."
                }
                self.testButton.enabled = true
            }
            break
        case .PUSHKEY_REGISTERED:
            // Step 5: OPTIONAL! Fetch all protocols for participant
            // ie. protocolId = -1 and metadataType = SPADESMetadataType.SENSOR_SERIAL_NUMBER
            SPADESManager.FetchProtocol(mobileUser!, accessToken: self.accessToken, protocolId: -1, metadataType: .SENSOR_SERIAL_NUMBER) {
                (response, json) in
                print(response)
                if response == .SUCCESS {
                    self.appState = .PROTOCOL_ALL_FETCHED
                    self.allProtocolFetchedText.text = "(Optional) All protocols fetched..."
                    print(json)
                }
                self.testButton.enabled = true
            }
            break
        case .PROTOCOL_ALL_FETCHED:
            // Step 6: OPTIONAL! Fetch a specific protocol for participant
            // ie. protocolId >= 0 and metadataType = SPADESMetadataType.PARTICIPANT_ID
            SPADESManager.FetchProtocol(mobileUser!, accessToken: self.accessToken, protocolId: 1, metadataType: .PARTICIPANT_ID) {
                (response, json) in
                print(response)
                if response == .SUCCESS {
                    self.appState = .PROTOCOL_ONE_FETCHED
                    self.oneProtocolFetchedText.text = "(Optional) Protocol id=1 fetched..."
                    print(json)
                } else {
                    
                }
                self.testButton.enabled = true
            }
            break
        case .PROTOCOL_ONE_FETCHED:
            // Step 7: OPTIONAL! Upload a file to SPADES. AWS information needed!
            // Set file path to an mHealth .csv.gz file in SampleFiles/ folder
            let testMHealthFilePath = "iPhone-STEPS-iOSx9x1.1112223333-STEPS.2016-01-22-19-22-34-310-M0500.sensor.csv"
            let fileFullPath = NSBundle.mainBundle().pathForResource(testMHealthFilePath, ofType: "gz")!
            SPADESManager.UploadFile(mobileUser!, awsInfo: self.awsInfo, fileFullPath: fileFullPath) {
                (response, fileGuid) in
                print(response)
                // Run the UI-update code asynchronously since UploadFile() runs in a separate background thread!
                dispatch_async(dispatch_get_main_queue(), {
                    if response == .SUCCESS {
                        self.appState = .FILE_UPLOADED
                        self.fileUploadedText.text = "(Optional) Test file uploaded successfully..."
                        print("Uploaded \(fileFullPath). FileGUID = \(fileGuid).")
                    }
                    self.testButton.enabled = true
                })
            }
            break
        case .FILE_UPLOADED:
            self.allDoneText.text = "All done!"
            break
        }
        
    }

}


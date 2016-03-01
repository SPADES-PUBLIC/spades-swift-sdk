# spades-swift-sdk
This is the Swift(2.0)-based SDK to allow 3rd-party applications to interact with SPADES.

Quick Start
-----------
This is a sample application which includes the SDK. This iOS application is run-able as-is with a few pre-requisites below:

1.  Download the repository and import into XCODE (v7.1+).

2.  In terminal, go to the root directory of the project and run `pod install` to install the required dependencies.

3.  Open `spadesLabSampleApp/ViewController.swift` and navigate to the `viewDidLoad()` function. Look for `FILL IN!` comments and add the required information. The SPADES API usage examples are in ViewController.swift's `TestButtonClicked()` function.

4.  Build and run the application. Once the app is running, press `Click Me` to go through all of the sample usages of the API. Also check console outputs for return values and errors.

Integration
-----------
To integrate the SDK into your Swift-based project:

1. Copy all files under `spadesLabSampleApp/SPADESSDK`.

2. Add the import lines in `spadesLabSampleApp/SupportingFiles/spadesLabSampleApp-Bridging-Header.h` to your own app's Objective-C bridging header file.

3. Add the required dependencies/pods in `Podfile` to your project's Podfile'. If your project does not use CocoaPods, please look for the pods' Frameworks (through Carthage) equivalents.

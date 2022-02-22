//
//  AzureIoTSwiftViewController.swift
//  AzureIoTSwiftSample
//
//  Created by Dane Walton on 2/14/22.
//

import Foundation
import MQTT
import NIOSSL
import AzureSDKForCSwift
import CAzureSDKForCSwift

var isProvisioningConnected: Bool = false;
var isDeviceProvisioned: Bool = false;
var sendTelemetry: Bool = false;
var gOperationID: String = ""

let base: String
if CommandLine.arguments.count > 1 {
    base = CommandLine.arguments[1]
} else {
    base = "."
}

/// Dispatch Queues to Send and Receive Messages
let sem = DispatchSemaphore(value: 0)
let queue = DispatchQueue(label: "a", qos: .background)

class DemoProvisioningClient: MQTTClientDelegate {
    
    /// Azure IoT Client
    private var AzProvClient : AzureIoTDeviceProvisioningClient! = nil
    
    /// MQTT Client
    private var mqttClient: MQTTClient! = nil
    
    public var assignedHub: String! = nil
    public var assignedDeviceID: String! = nil
    
    var delegateDispatchQueue: DispatchQueue {
        queue
    }

    public init(idScope: String, registrationID: String)
    {
        AzProvClient = AzureIoTDeviceProvisioningClient(idScope: idScope, registrationID: registrationID)

        let caCert: [UInt8] = Array(myBaltimore.utf8)
        let clientCert: [UInt8] = Array(myCert.utf8)
        let keyCert: [UInt8] = Array(myCertKey.utf8)

        let tlsConfiguration = try! TLSConfiguration.forClient(minimumTLSVersion: .tlsv11,
                                                               maximumTLSVersion: .tlsv12,
                                                               certificateVerification: .noHostnameVerification,
                                                               trustRoots: NIOSSLTrustRoots.certificates(NIOSSLCertificate.fromPEMBytes(caCert)),
                                                               certificateChain: NIOSSLCertificate.fromPEMBytes(clientCert).map { .certificate($0) },
                                                               privateKey: .privateKey(.init(bytes: keyCert, format: NIOSSLSerializationFormats.pem)))
        print("Client ID: \(AzProvClient.GetDeviceProvisioningClientID())")
        print("Username: \(AzProvClient.GetDeviceProvisioningUsername())")

        mqttClient = MQTTClient(
            host: "global.azure-devices-provisioning.net",
            port: 8883,
            clientID: AzProvClient.GetDeviceProvisioningClientID(),
            cleanSession: true,
            keepAlive: 30,
            username: AzProvClient.GetDeviceProvisioningUsername(),
            password: "",
            tlsConfiguration: tlsConfiguration
        )
        mqttClient.tlsConfiguration = tlsConfiguration
        mqttClient.delegate = self
    }

/// Needed Functions for MQTTClientDelegate
    func mqttClient(_ client: MQTTClient, didReceive packet: MQTTPacket) {
        switch packet {
        case let packet as ConnAckPacket:
            print("[Provisioning] Connack Received: \(packet)")
            isProvisioningConnected = true;
            
        case let packet as PublishPacket:
            print("[Provisioning] Publish Received");
            print("[Provisioning] Publish Topic: \(packet.topic)");
            print("[Provisioning] Publish Payload \(String(decoding: packet.payload, as: UTF8.self))");

            let provResponse: AzureIoTProvisioningRegisterResponse = AzProvClient.ParseRegistrationTopicAndPayload(topic: packet.topic, payload: String(decoding: packet.payload, as: UTF8.self))
            gOperationID = provResponse.OperationID

            if provResponse.RegistrationState.AssignedHubHostname.count > 0
            {
                print("[Provisioning] Assigned Hub: \(provResponse.RegistrationState.AssignedHubHostname)")
                isDeviceProvisioned = true;
                
                assignedHub = provResponse.RegistrationState.AssignedHubHostname
                assignedDeviceID = provResponse.RegistrationState.DeviceID
            }
            
        case let packet as SubAckPacket:
            print("[Provisioning] Suback Received: \(packet)");

        default:
            print("[Provisioning] Packet Received: \(packet)")
        }
    }

    func mqttClient(_: MQTTClient, didChange state: ConnectionState) {
        if state == .disconnected {
            print("[Provisioning] MQTT state:\(state)")
        }
    }

    func mqttClient(_: MQTTClient, didCatchError error: Error) {
        print("[Provisioning] Error: \(error)")
    }

    public func connectToProvisioning() {
        print("[Provisioning] Connecting to Provisioning")
        mqttClient.connect()
    }
    
    public func disconnectFromProvisioning() {
        print("[Provisioning] Disconnecting from Provisioning")
        mqttClient.disconnect()
    }

    public func subscribeToAzureDeviceProvisioningFeature() {
        print("[Provisioning] Subscribing to Provisioning")
        let deviceProvisioningTopic = AzProvClient.GetDeviceProvisioningSubscribeTopic()
        print("[Provisioning] Subscribing to topic: \(deviceProvisioningTopic)")
        mqttClient.subscribe(topic: deviceProvisioningTopic, qos: QOS.1)
    }

    public func sendDeviceProvisioningRequest() {
        print("[Provisioning] Requesting to be Provisioned")
        let deviceProvisioningRequestTopic = AzProvClient.GetDeviceProvisioningRegistrationPublishTopic()
        mqttClient.publish(topic: deviceProvisioningRequestTopic, retain: false, qos: QOS.1, payload: "")
    }

    public func sendDeviceProvisioningPollingRequest(operationID: String) {
        print("[Provisioning] Querying Provisioning")
        let deviceProvisioningQueryTopic = AzProvClient.GetDeviceProvisioningQueryTopic(operationID: operationID)
        mqttClient.publish(topic: deviceProvisioningQueryTopic, retain: false, qos: QOS.1, payload: "")
    }
}

class DemoHubClient: MQTTClientDelegate {

    /// Azure IoT Client
    private var AzHubClient : AzureIoTHubClient! = nil

    /// MQTT Client
    private var mqttClient: MQTTClient! = nil
    
    var delegateDispatchQueue: DispatchQueue {
        queue
    }

    public init(iothub: String, deviceId: String)
    {
        AzHubClient = AzureIoTHubClient(iothubUrl: iothub, deviceId: deviceId)

        let caCert: [UInt8] = Array(myBaltimore.utf8)
        let clientCert: [UInt8] = Array(myCert.utf8)
        let keyCert: [UInt8] = Array(myCertKey.utf8)

        let tlsConfiguration = try! TLSConfiguration.forClient(minimumTLSVersion: .tlsv11,
                                                               maximumTLSVersion: .tlsv12,
                                                               certificateVerification: .noHostnameVerification,
                                                               trustRoots: NIOSSLTrustRoots.certificates(NIOSSLCertificate.fromPEMBytes(caCert)),
                                                               certificateChain: NIOSSLCertificate.fromPEMBytes(clientCert).map { .certificate($0) },
                                                               privateKey: .privateKey(.init(bytes: keyCert, format: NIOSSLSerializationFormats.pem)))
        mqttClient = MQTTClient(
            host: iothub,
            port: 8883,
            clientID: AzHubClient.GetClientID(),
            cleanSession: true,
            keepAlive: 30,
            username: AzHubClient.GetUserName(),
            password: "",
            tlsConfiguration: tlsConfiguration
        )
        mqttClient.tlsConfiguration = tlsConfiguration
        mqttClient.delegate = self
    }

/// Needed Functions for MQTTClientDelegate

    func mqttClient(_ client: MQTTClient, didReceive packet: MQTTPacket) {
        switch packet {
        case let packet as ConnAckPacket:
            print("[IoT Hub] Connack Received: \(packet)")
            sendTelemetry = true;
            
        case let packet as PublishPacket:
            print("[IoT Hub] Publish Received: \(packet)");
            print("[IoT Hub] Publish Topic: \(packet.topic)");

            var commandRequest: AzureIoTHubCommandRequest = AzureIoTHubCommandRequest()
            var propertiesMessage: AzureIoTHubPropertiesMessage = AzureIoTHubPropertiesMessage()

            if az_result_succeeded(AzHubClient.ParseCommandsReceivedTopic(topic: packet.topic, message: &commandRequest))
            {
                print("[IoT Hub] Received Command Request for: \(commandRequest.commandName)")
                print("[IoT Hub] Command Payload \(String(decoding: packet.payload, as: UTF8.self))");
            }
            else if az_result_succeeded(AzHubClient.ParsePropertiesReceivedTopic(topic: packet.topic, message: &propertiesMessage))
            {
                print("[IoT Hub] Received Properties Request")
                print("[IoT Hub] Properties Payload \(String(decoding: packet.payload, as: UTF8.self))");
            }

        default:
            print("[IoT Hub] Packet Received: \(packet)")
        }
    }

    func mqttClient(_: MQTTClient, didChange state: ConnectionState) {
        if state == .disconnected {
            sem.signal()
        }
        print("[IoT Hub] MQTT state: \(state)")
    }

    func mqttClient(_: MQTTClient, didCatchError error: Error) {
        print("[IoT Hub] Error: \(error)")
    }

/// ****************** PRIVATE ******************** ///



/// ****************** PUBLIC ******************** ///

/// Sends a message to the IoT hub
    public func sendMessage() {
        let swiftString = AzHubClient.GetTelemetryPublishTopic()

        let telem_payload = "Hello iOS"
        print("[IoT Hub] Sending a message to topic: \(swiftString)")
        print("[IoT Hub] Sending a message: \(telem_payload)")

        mqttClient.publish(topic: swiftString, retain: false, qos: QOS.1, payload: telem_payload)
    }

    public func connectToIoTHub() {
        print("[IoT Hub] Connecting to IoT Hub")
        mqttClient.connect()
    }

    public func disconnectFromIoTHub() {
        mqttClient.disconnect();
    }

    public func subscribeToAzureIoTHubFeatures() {
        print("[IoT Hub] Subscribing to IoT Hub Features")
        // Commands
        let commandsTopic = AzHubClient.GetCommandsSubscribeTopic()
        mqttClient.subscribe(topic: commandsTopic, qos: QOS.1)
        
        // Twin Response
        let twinResponseTopic = AzHubClient.GetPropertiesResponseSubscribeTopic()
        mqttClient.subscribe(topic: twinResponseTopic, qos: QOS.1)

        // Twin Patch
        let twinPatchTopic = AzHubClient.GetPropertiesWritablePatchSubscribeTopic()
        mqttClient.subscribe(topic: twinPatchTopic, qos: QOS.1)

    }
}

///********** Provisioning Flow **********///

var provisioningDemoClient = DemoProvisioningClient(idScope: myScopeID, registrationID: myRegistrationID)

provisioningDemoClient.connectToProvisioning()

while(!isProvisioningConnected) {}

provisioningDemoClient.subscribeToAzureDeviceProvisioningFeature()

provisioningDemoClient.sendDeviceProvisioningRequest()

var start = DispatchTime.now()
var end = DispatchTime.now()

while(!isDeviceProvisioned) {

    // Poll every 5 seconds to ask if provisioned
    end = DispatchTime.now()
    let diffTime = end.uptimeNanoseconds - start.uptimeNanoseconds
    
    if Double(diffTime) / 1_000_000_000 > 5
    {
        start = DispatchTime.now()
        provisioningDemoClient.sendDeviceProvisioningPollingRequest(operationID: gOperationID)
    }
}

provisioningDemoClient.disconnectFromProvisioning()

///********** Hub Flow **********///

var hubDemoHubClient = DemoHubClient(iothub: provisioningDemoClient.assignedHub, deviceId: provisioningDemoClient.assignedDeviceID)

hubDemoHubClient.connectToIoTHub()

while(!sendTelemetry) {

    // Keep trying every 5 seconds to connect
    var start = DispatchTime.now()
    var end = DispatchTime.now()

    while(!isDeviceProvisioned) {
        
        end = DispatchTime.now()
        let diffTime = end.uptimeNanoseconds - start.uptimeNanoseconds
        
        if Double(diffTime) / 1_000_000_000 > 5
        {
            start = DispatchTime.now()
            hubDemoHubClient.connectToIoTHub()
        }
    }
}

hubDemoHubClient.subscribeToAzureIoTHubFeatures()

for x in 0...5
{
    queue.asyncAfter(deadline: .now() + DispatchTimeInterval.seconds(x))
    {
        hubDemoHubClient.sendMessage()
    }
}

queue.asyncAfter(deadline: .now() + 20) {
    print("Ending")
    hubDemoHubClient.disconnectFromIoTHub()
}

sem.wait()

import Foundation
import MQTT
import NIOSSL
import AzureSDKForCSwift
import CAzureSDKForCSwift
import AzureIoTUniversalMiddleware
import AzureIoTMiddlewareForSwift

let base: String
if CommandLine.arguments.count > 1 {
    base = CommandLine.arguments[1]
} else {
    base = "."
}

let totalNumberOfTelemetryMessagesToSend = 10

var azureIoT: AzureIoT = AzureIoT(
    idScope: myIdScope, registrationId: myRegistrationId, deviceKey: myDeviceKey,
    pnpModelId: myPnPModelId)

var retCode = azureIoT.start()

var lastTelemetrySendTime: Date = Date()
var counter: UInt32 = 0

while (counter < totalNumberOfTelemetryMessagesToSend && 
       azureIoT.getStatus().rawValue != azure_iot_error.rawValue) {

    azureIoT.processLoop()

    if (Date().timeIntervalSince(lastTelemetrySendTime) >= telemetryFrequencyInSeconds) {
        if (azureIoT.getStatus().rawValue == azure_iot_connected.rawValue) {
            print("Sending telemetry...")

            if (azureIoT.sendTelemetry(message: "Hello \(counter)")) {
                counter += 1
            } else {
                print("Failed sending telemetry.")
            }

        }

        lastTelemetrySendTime = Date()
    }
}

_ = azureIoT.stop()

print("Bye...")

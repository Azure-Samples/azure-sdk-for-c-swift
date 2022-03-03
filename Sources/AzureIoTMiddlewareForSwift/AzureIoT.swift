import Foundation
import MQTT
import NIOSSL
import Crypto
import AzureIoTUniversalMiddleware

extension StringProtocol {
    subscript(offset: Int) -> Character {
        self[index(startIndex, offsetBy: offset)]
    }
}

public class AzureIoT: MQTTClientDelegate {
    // Section 1: Variables
    private var azureIotConfig: azure_iot_config_t = azure_iot_config_t()
    private var internalClient: azure_iot_t = azure_iot_t()
    private var internalBuffer: AzSpan = AzSpan(size: 2048);

    private var MQTT_PASSWORD_LIFETIME_IN_MINUTES: UInt32 = 60

    private var userAgent: AzSpan = AzSpan(text: "c%2F1.3.0-beta.1(swift)")

    public var mqttClient: MQTTClient! = nil
    public var mqttPublishPacketId: UInt32 = 0
    public var mqttSubscribePacketId: UInt32 = 0
    
    // Section 2: Implementation of MQTTClientDelegate.

    let mqttQueue = DispatchQueue(label: "a", qos: .background)

    public var delegateDispatchQueue: DispatchQueue {
        mqttQueue
    }

    public func mqttClient(_ client: MQTTClient, didReceive packet: MQTTPacket) {
        switch packet {
        case let packet as ConnAckPacket:
            print("< CONNACK \(packet.returnCode)")
            _ = azure_iot_mqtt_client_connected(&internalClient)
        case let packet as PubAckPacket:
            print("< PUBACK \(packet.identifier)")
            _ = azure_iot_mqtt_client_publish_completed(&internalClient, Int32(packet.identifier))
        case let packet as SubAckPacket:
            print("< SUBACK \(packet.identifier) | \(packet.returnCodes)")
            _ = azure_iot_mqtt_client_subscribe_completed(&internalClient, Int32(packet.identifier))
        case let packet as PublishPacket:
            print("< PUBLISH \(packet.identifier) | \(packet.topic) | \(packet.qos)")
            print("  Payload: \(String(decoding: packet.payload, as: UTF8.self))")

            var mqttMessage = mqtt_message_t()
            mqttMessage.topic = AzSpan(text: packet.topic).toCAzSpan()
            mqttMessage.payload = AzSpan(data: packet.payload).toCAzSpan()
            mqttMessage.qos = mqtt_qos_t(rawValue: UInt32(packet.qos.rawValue))

            _ = azure_iot_mqtt_client_message_received(&internalClient, &mqttMessage)
        default:
            print("Packet \(packet)")
        }
    }

    public func mqttClient(_: MQTTClient, didChange state: ConnectionState) {
        if state == .connected {
        }
        else if state == .disconnected {
            _ = azure_iot_mqtt_client_disconnected(&internalClient)
        }
        print("[MQTT] \(state)")
    }

    public func mqttClient(_: MQTTClient, didCatchError error: Error) {
        print("[MQTT] Error: \(error)")
    }

    // Section 3: Callbacks for Azure IoT Universal Middleware.

    let mqttClientInitFunction: mqtt_client_init_function_t = { userContext, mqttClientConfig, mqttClientHandle in
        print("Connecting MQTT client")

        var mySelf: AzureIoT = Unmanaged<AzureIoT>.fromOpaque(userContext!).takeUnretainedValue()

        let address: String = (AzSpan(span: mqttClientConfig!.pointee.address)).toString()
        let port = Int(mqttClientConfig!.pointee.port)
        let clientId: String = (AzSpan(span: mqttClientConfig!.pointee.client_id)).toString()
        let username: String = (AzSpan(span: mqttClientConfig!.pointee.username)).toString()
        let password: String = (AzSpan(span: mqttClientConfig!.pointee.password)).toString()

        let caCert = "/home/ewertons/code/work/s1/azure-sdk-for-c-swift/certs/baltimore.pem"
        // let clientCert = "\(base)/certs/client.pem"
        // let keyCert = "\(base)/certs/client-key.pem"
        var tlsConfiguration = TLSConfiguration.makeClientConfiguration()
        tlsConfiguration.minimumTLSVersion = .tlsv11
        tlsConfiguration.maximumTLSVersion = .tlsv12
        tlsConfiguration.trustRoots = try! NIOSSLTrustRoots.certificates(NIOSSLCertificate.fromPEMFile(caCert))
        tlsConfiguration.certificateVerification = .noHostnameVerification

        mySelf.mqttClient = MQTTClient(
            host: address,
            port: port,
            clientID: clientId,
            cleanSession: true,
            keepAlive: 30,
            username: username,
            password: password,
            tlsConfiguration: tlsConfiguration
        )
        mySelf.mqttClient.tlsConfiguration = tlsConfiguration
        mySelf.mqttClient.delegate = mySelf

        mqttClientHandle!.initialize(to: &mySelf.mqttClient)

        print("> CONNECT \(address):\(port)")
        print("  ClientId: \(clientId)")
        print("  Username: \(username)")

        mySelf.mqttClient.connect()

        return 0
    }

    let mqttClientDeinitFunction: mqtt_client_deinit_function_t = { userContext, mqttClientHandle in
        print("Disconnecting MQTT client")

        var mySelf: AzureIoT = Unmanaged<AzureIoT>.fromOpaque(userContext!).takeUnretainedValue()
        mySelf.mqttClient.disconnect()

        return 0
    }

    let mqttClientPublishFunction: mqtt_client_publish_function_t = {
        userContext, mqttClientHandle, mqttMessage in

        var mySelf: AzureIoT = Unmanaged<AzureIoT>.fromOpaque(userContext!).takeUnretainedValue()
        var mqttClient: MQTTClient = mySelf.mqttClient
        var topic: String = (AzSpan(span: mqttMessage!.pointee.topic)).toString()
        let qos: QoS = QoS(rawValue: UInt8(mqttMessage!.pointee.qos.rawValue))!
        let payload: Data = (AzSpan(span: mqttMessage!.pointee.payload)).toData()

        // The last byte must be dropped because it is a null-terminator.
        topic.removeLast()

        mySelf.mqttPublishPacketId += 1

        print("> PUBLISH \(mySelf.mqttPublishPacketId) | \(topic) | \(qos)")
        print("  Payload: \(String(decoding: payload, as: UTF8.self))")

        mqttClient.publish(topic: topic, retain: false, qos: qos, payload: payload, identifier: UInt16(mySelf.mqttPublishPacketId))

        return Int32(mySelf.mqttPublishPacketId)
    }

    let mqttClientSubscribeFunction: mqtt_client_subscribe_function_t = {
        userContext, mqttClientHandle, topic, qos in
        var mySelf: AzureIoT = Unmanaged<AzureIoT>.fromOpaque(userContext!).takeUnretainedValue()
        var mqttClient: MQTTClient = mySelf.mqttClient
        let topicString: String = (AzSpan(span: topic)).toString()
        var qosValue: QoS = QoS(rawValue: UInt8(qos.rawValue))!

        mySelf.mqttSubscribePacketId += 1

        print("> SUBSCRIBE \(mySelf.mqttSubscribePacketId) | \(topicString) | \(qosValue)")
        
        mqttClient.subscribe(topic: topicString, qos: qosValue, identifier: UInt16(mySelf.mqttSubscribePacketId))

        return Int32(mySelf.mqttSubscribePacketId)
    }

    let base64Decode: base64_decode_function_t = {
        data, data_length, decoded, decoded_size, decoded_length in
        let encodedData = Data(bytes: data!, count: data_length)
        let decodedData = Data(base64Encoded: encodedData, options: .ignoreUnknownCharacters)

        if (decodedData!.count > decoded_size)
        {
            return 1 // Error
        }
        else
        {
            decodedData!.copyBytes(to: decoded!, count: decodedData!.count)
            decoded_length!.initialize(to: decodedData!.count)
            return 0
        }
    }

    let base64Encode: base64_encode_function_t = {
        data, data_length, encoded, encoded_size, encoded_length in
        let decodedData = Data(bytes: data!, count: data_length)
        let encodedData = decodedData.base64EncodedData()

        if (encodedData.count > encoded_size)
        {
            return 1 // Error
        }
        else
        {
            encodedData.copyBytes(to: encoded!, count: encodedData.count)
            encoded_length!.initialize(to: encodedData.count)
            return 0
        }
    }

    let mbedtlsHmacSha256: hmac_sha256_encryption_function_t = { 
        key, key_length, payload, payload_length, encrypted_payload, encrypted_payload_size in

        let symmetricKey = SymmetricKey(data: Data(bytes: key!, count: key_length))
        let payloadData = Data(bytes: payload!, count: payload_length)
        let signature = HMAC<SHA256>.authenticationCode(for: payloadData, using: symmetricKey)
        let encryptedPayload = Data(signature)

        if (encryptedPayload.count > encrypted_payload_size)
        {
            return 1
        }
        else
        {
            encryptedPayload.copyBytes(to: encrypted_payload!, count: encryptedPayload.count)
            return 0
        }
    }

    let onPropertiesUpdateCompleted: properties_update_completed_t = { request_id, status_code in
        print("Properties update \(request_id) completed: \(status_code)")
        
    }

    let onPropertiesReceived: properties_received_t = {
        properties in
        var propertiesSpan = AzSpan(span: properties)
        print("Properties received: \(propertiesSpan.toString())")
    }

    let onCommandRequestReceived: command_request_received_t = {
        command in
        print("Command received: \(AzSpan(span: command.command_name).toString())")
    }

    // Section 4: Initializers.

    public init(iotHubFqdn: String, deviceId: String, deviceKey: String, pnpModelId: String? = nil) {
        initializeAzureIoT(
            useDeviceProvisioning: false,
            pnpModelId: AzSpan(text: pnpModelId),
            iotHubFqdn: AzSpan(text: iotHubFqdn),
            deviceId: AzSpan(text: deviceId),
            deviceKey: AzSpan(text: deviceKey),
            idScope: AzSpan.NullAzSpan(),
            registrationId: AzSpan.NullAzSpan()
            )
    }

    public init(idScope: String, registrationId: String, deviceKey: String, pnpModelId: String? = nil) {
        initializeAzureIoT(
            useDeviceProvisioning: true,
            pnpModelId: AzSpan(text: pnpModelId),
            iotHubFqdn: AzSpan.NullAzSpan(),
            deviceId: AzSpan.NullAzSpan(),
            deviceKey: AzSpan(text: deviceKey),
            idScope: AzSpan(text: idScope),
            registrationId: AzSpan(text: registrationId)
            )
    }

    private func initializeAzureIoT(
        useDeviceProvisioning: Bool,
        pnpModelId: AzSpan,
        iotHubFqdn: AzSpan, deviceId: AzSpan, deviceKey: AzSpan,
        idScope: AzSpan, registrationId: AzSpan) {
        set_console_logging_function()

        azureIotConfig.user_agent = userAgent.toCAzSpan()
        azureIotConfig.model_id = pnpModelId.toCAzSpan()
        azureIotConfig.use_device_provisioning = useDeviceProvisioning
        azureIotConfig.iot_hub_fqdn = iotHubFqdn.toCAzSpan()
        azureIotConfig.device_id = deviceId.toCAzSpan()
        azureIotConfig.device_key = deviceKey.toCAzSpan()
        azureIotConfig.dps_id_scope = idScope.toCAzSpan()
        azureIotConfig.dps_registration_id = registrationId.toCAzSpan()
        azureIotConfig.data_buffer = internalBuffer.toCAzSpan()
        azureIotConfig.sas_token_lifetime_in_minutes = MQTT_PASSWORD_LIFETIME_IN_MINUTES
        azureIotConfig.mqtt_client_interface.mqtt_client_init = mqttClientInitFunction
        azureIotConfig.mqtt_client_interface.mqtt_client_deinit = mqttClientDeinitFunction
        azureIotConfig.mqtt_client_interface.mqtt_client_subscribe = mqttClientSubscribeFunction
        azureIotConfig.mqtt_client_interface.mqtt_client_publish = mqttClientPublishFunction
        azureIotConfig.data_manipulation_functions.hmac_sha256_encrypt = mbedtlsHmacSha256
        azureIotConfig.data_manipulation_functions.base64_decode = base64Decode
        azureIotConfig.data_manipulation_functions.base64_encode = base64Encode
        azureIotConfig.on_properties_update_completed = onPropertiesUpdateCompleted
        azureIotConfig.on_properties_received = onPropertiesReceived
        azureIotConfig.on_command_request_received = onCommandRequestReceived
        azureIotConfig.user_context = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())

        azure_iot_init(&internalClient, &azureIotConfig)
    }

    // Section 6: Public methods.
    public func start() -> Bool {
        return (azure_iot_start(&internalClient) == 0)
    }

    public func stop() -> Bool {
        return (azure_iot_stop(&internalClient) == 0)
    }

    public func getStatus() -> azure_iot_status_t {
        return azure_iot_get_status(&internalClient)
    }

    public func sendTelemetry(message: String) -> Bool {
        let messageSpan = AzSpan(text: message + "\0")
        return azure_iot_send_telemetry(&internalClient, messageSpan.toCAzSpan()) == 0
    }

    public func processLoop() -> Void {
        azure_iot_do_work(&internalClient)
    }

    // Section 7: Private methods
}

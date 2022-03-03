import AzureSDKForCSwift

private func makeCString(from str: String) -> UnsafeMutablePointer<Int8> {
    let count = str.utf8CString.count
    let result: UnsafeMutableBufferPointer<Int8> = UnsafeMutableBufferPointer<Int8>.allocate(capacity: count)
    _ = result.initialize(from: str.utf8CString)
    return result.baseAddress!
}

public struct AzureIoTProvisioningRegistrationState
{
    public var AssignedHubHostname: String
    public var DeviceID: String
    public var ErrorCode: az_iot_status
    public var ExtendedErrorCode: UInt32
    public var ErrorMessage: String
    public var ErrorTrackingID: String
    public var ErrorTimestamp: String
    
    init(embeddedRegistrationState: az_iot_provisioning_client_registration_state )
    {
        var AssignedHubString = ""
        if az_span_size(embeddedRegistrationState.assigned_hub_hostname) > 0
        {
            let AssignedHubSpan = AzSpan(span: embeddedRegistrationState.assigned_hub_hostname)
            AssignedHubString = AssignedHubSpan.toString()
        }
        
        var DeviceIDString = ""
        if az_span_size(embeddedRegistrationState.device_id) > 0
        {
            let DeviceIDSpan = AzSpan(span: embeddedRegistrationState.device_id)
            DeviceIDString = DeviceIDSpan.toString()
        }
        
        var ErrorMessageString = ""
        if az_span_size(embeddedRegistrationState.error_message) > 0
        {
            let ErrorMessageSpan = AzSpan(span: embeddedRegistrationState.error_message)
            ErrorMessageString = ErrorMessageSpan.toString()
        }
        
        var ErrorTrackingIDString = ""
        if az_span_size(embeddedRegistrationState.error_tracking_id) > 0
        {
            let ErrorTrackingIDSpan = AzSpan(span: embeddedRegistrationState.error_tracking_id)
            ErrorTrackingIDString = ErrorTrackingIDSpan.toString()
        }
        
        var ErrorTimestampString = ""
        if az_span_size(embeddedRegistrationState.error_timestamp) > 0
        {
            let ErrorTimestampIDSpan = AzSpan(span: embeddedRegistrationState.error_timestamp)
            ErrorTimestampString = ErrorTimestampIDSpan.toString()
        }
        
        self.AssignedHubHostname = AssignedHubString
        self.DeviceID = DeviceIDString
        self.ErrorCode = embeddedRegistrationState.error_code
        self.ExtendedErrorCode = embeddedRegistrationState.extended_error_code
        self.ErrorMessage = ErrorMessageString
        self.ErrorTrackingID = ErrorTrackingIDString
        self.ErrorTimestamp = ErrorTimestampString
    }
}

public struct AzureIoTProvisioningRegisterResponse
{
    public var OperationID: String
    public var Status: az_iot_status
    public var OperationStatus: az_iot_provisioning_client_operation_status
    public var RetryAfterSeconds: UInt32
    public var RegistrationState: AzureIoTProvisioningRegistrationState
    
    init(embeddedResponse: az_iot_provisioning_client_register_response)
    {
        let opIDSpan = AzSpan(span: embeddedResponse.operation_id)
        let opIDString = opIDSpan.toString()
        
        self.OperationID = opIDString
        self.Status = embeddedResponse.status
        self.OperationStatus = embeddedResponse.operation_status
        self.RetryAfterSeconds = embeddedResponse.retry_after_seconds
        self.RegistrationState = AzureIoTProvisioningRegistrationState(embeddedRegistrationState: embeddedResponse.registration_state)
    }
}

public class AzureIoTDeviceProvisioningClient {
    
    private(set) var embeddedProvClient: az_iot_provisioning_client! = nil
    
    public init(idScope: String, registrationID: String)
    {
        embeddedProvClient = az_iot_provisioning_client()

        let globalEndpointSpan = AzSpan(text: "global.azure-devices-provisioning.net")
        let idScopeSpan = AzSpan(text: idScope)
        let registrationIDSpan = AzSpan(text: registrationID)
        
        _ = az_iot_provisioning_client_init(&embeddedProvClient, globalEndpointSpan.toCAzSpan(), idScopeSpan.toCAzSpan(), registrationIDSpan.toCAzSpan(), nil)
    }
    
    /// PROVISIONING
    public func GetDeviceProvisioningSubscribeTopic() -> String
    {
        return AZ_IOT_PROVISIONING_CLIENT_REGISTER_SUBSCRIBE_TOPIC
    }
    
    public func GetDeviceProvisioningClientID() -> String {
        var clientIDArray = [CChar](repeating: 0, count: 100)
        var clientIDLength : Int = 0
        
        let _ : az_result = az_iot_provisioning_client_get_client_id(&self.embeddedProvClient, &clientIDArray, 100, &clientIDLength )
        
        return String(cString: clientIDArray)
    }
    
    public func GetDeviceProvisioningUsername() -> String
    {
        var UsernameArray = [CChar](repeating: 0, count: 100)
        var UsernameLength : Int = 0
        
        let _ : az_result = az_iot_provisioning_client_get_user_name(&self.embeddedProvClient, &UsernameArray, 100, &UsernameLength )
        
        return String(cString: UsernameArray)
    }
    
    public func GetDeviceProvisioningRegistrationPublishTopic() -> String
    {
        var TopicArray = [CChar](repeating: 0, count: 100)
        var TopicLength : Int = 0
        
        let _ : az_result = az_iot_provisioning_client_register_get_publish_topic(&self.embeddedProvClient, &TopicArray, 100, &TopicLength )
        
        return String(cString: TopicArray)
    }
    
    public func GetDeviceProvisioningQueryTopic(operationID: String) -> String
    {
        var TopicArray = [CChar](repeating: 0, count: 150)
        var TopicLength : Int = 0

        let opIDSpan = AzSpan(text: operationID)
        
        let _ : az_result = az_iot_provisioning_client_query_status_get_publish_topic(&self.embeddedProvClient, opIDSpan.toCAzSpan(), &TopicArray, 150, &TopicLength )
        
        return String(cString: TopicArray)
    }
    
    public func ParseRegistrationTopicAndPayload(topic: String, payload: String) -> AzureIoTProvisioningRegisterResponse
    {
        let topicSpan = AzSpan(text: topic)
        let payloadSpan = AzSpan(text: payload)

        var embeddedRequestResponse: az_iot_provisioning_client_register_response = az_iot_provisioning_client_register_response()
        _ = az_iot_provisioning_client_parse_received_topic_and_payload(&self.embeddedProvClient, topicSpan.toCAzSpan(), payloadSpan.toCAzSpan(), &embeddedRequestResponse)
        
        let responseStruct: AzureIoTProvisioningRegisterResponse = AzureIoTProvisioningRegisterResponse(embeddedResponse: embeddedRequestResponse)
        
        return responseStruct
    }
}

/// IOT HUB FEATURES

public struct AzureIoTHubCommandRequest
{
    public var requestID: String = ""
    public var componentName: String = ""
    public var commandName: String = ""
    
    public init() {}
    public init(embeddedCommandRequest: az_iot_hub_client_command_request)
    {
        let requestIDSpan = AzSpan(span: embeddedCommandRequest.request_id)
        self.requestID = requestIDSpan.toString()

        let commandNameSpan = AzSpan(span: embeddedCommandRequest.command_name)
        self.commandName = commandNameSpan.toString()
        
        // Optional depending on the command
        if az_span_size(embeddedCommandRequest.component_name) > 0
        {
            let componentNameSpan = AzSpan(span: embeddedCommandRequest.component_name)
            self.componentName = componentNameSpan.toString()
        }
    }
}

public struct AzureIoTHubPropertiesMessage
{
    public var requestID: String = ""
    public var responseType: az_iot_hub_client_properties_message_type = AZ_IOT_HUB_CLIENT_PROPERTIES_MESSAGE_TYPE_ERROR
    public var status: az_iot_status = AZ_IOT_STATUS_UNKNOWN
    
    public init() {}
    public init(embeddedPropertiesMessage: az_iot_hub_client_properties_message)
    {
        self.responseType = embeddedPropertiesMessage.message_type
        self.status = embeddedPropertiesMessage.status
        
        // Only some messages have a request ID
        if az_span_size(embeddedPropertiesMessage.request_id) > 0
        {
            let requestIDSpan = AzSpan(span: embeddedPropertiesMessage.request_id)
            self.requestID = requestIDSpan.toString()
        }
    }
}

public struct AzureIoTHubMessageProperties
{
    private var embeddedMessageProperties: az_iot_message_properties = az_iot_message_properties()
    
    public init() {}
    public init(embeddedMessageProperties: az_iot_message_properties)
    {
        self.embeddedMessageProperties = embeddedMessageProperties
    }
    
    public mutating func FindProperty(propertyName: String) -> String?
    {
        let propertyNameSpan = AzSpan(text: propertyName)
        var outputSpan: az_span = az_span()
        _ = az_iot_message_properties_find(&self.embeddedMessageProperties, propertyNameSpan.toCAzSpan(), &outputSpan)
        
        if az_span_size(outputSpan) > 0
        {
            let outputTempSpan = AzSpan(span: outputSpan)
            return outputTempSpan.toString()
        }
        else
        {
            return nil
        }
    }
    
    public mutating func PropertiesNext() -> (name: String, value: String)?
    {
        var nameSpan: az_span = az_span()
        var valueSpan: az_span = az_span()
        _ = az_iot_message_properties_next(&self.embeddedMessageProperties, &nameSpan, &valueSpan)
        
        if az_span_size(nameSpan) > 0
        {
            let nameTempSpan = AzSpan(span: nameSpan)
            let valueTempSpan = AzSpan(span: valueSpan)

            return (nameTempSpan.toString(), valueTempSpan.toString())
        }
        else
        {
            return nil
        }
    }
}

public struct AzureIoTHubC2DMessage
{
    public var properties: AzureIoTHubMessageProperties = AzureIoTHubMessageProperties()

    public init() {}
    public init(embeddedC2DMessage: az_iot_hub_client_c2d_request)
    {
        properties = AzureIoTHubMessageProperties(embeddedMessageProperties: embeddedC2DMessage.properties)
    }
}

public class AzureIoTHubClient {
    private(set) var embeddedHubClient: az_iot_hub_client! = nil
    
    public init(iothubUrl: String, deviceId: String)
    {
        embeddedHubClient = az_iot_hub_client()
        var embeddedHubClientOptions = az_iot_hub_client_options()
        
        let userAgentSpan = AzSpan(text: "azsdk-c%2Fswift%2F\(AZ_SDK_VERSION_STRING)")
        embeddedHubClientOptions.user_agent = userAgentSpan.toCAzSpan()
        
        let iothubSpan = AzSpan(text: iothubUrl)
        let deviceIDSpan = AzSpan(text: deviceId)
        
        _ = az_iot_hub_client_init(&embeddedHubClient, iothubSpan.toCAzSpan(), deviceIDSpan.toCAzSpan(), &embeddedHubClientOptions)
    }
    
    public func GetUserName() -> String
    {
        var usernameCharArray = [CChar](repeating: 0, count: 150)
        var usernameLength : Int = 0
        
        let _ : az_result = az_iot_hub_client_get_user_name(&self.embeddedHubClient, &usernameCharArray, 150, &usernameLength )
        return String(cString: usernameCharArray)
    }
    
    public func GetClientID() -> String
    {
        var clientIDCharArray = [CChar](repeating: 0, count: 150)
        var clientIDLength : Int = 0
        
        let _ : az_result = az_iot_hub_client_get_client_id(&self.embeddedHubClient, &clientIDCharArray, 150, &clientIDLength )
        return String(cString: clientIDCharArray)
    }
    
    public func GetTelemetryPublishTopic() -> String
    {
        var topicCharArray = [CChar](repeating: 0, count: 100)
        var topicLength : Int = 0
        
        let _ : az_result = az_iot_hub_client_telemetry_get_publish_topic(&self.embeddedHubClient, nil, &topicCharArray, 100, &topicLength )
        
        return String(cString: topicCharArray)
    }

    public func GetC2DSubscribeTopic() -> String
    {
        return AZ_IOT_HUB_CLIENT_C2D_SUBSCRIBE_TOPIC
    }

    public func ParseC2DReceivedTopic(topic: String, message: inout AzureIoTHubC2DMessage) -> az_result
    {
        var embeddedC2DMessage: az_iot_hub_client_c2d_request = az_iot_hub_client_c2d_request()
        
        let topicSpan = AzSpan(text: topic)
        let azResult : az_result = az_iot_hub_client_c2d_parse_received_topic(&self.embeddedHubClient, topicSpan.toCAzSpan(), &embeddedC2DMessage)
        
        if az_result_succeeded(azResult)
        {
            message = AzureIoTHubC2DMessage(embeddedC2DMessage: embeddedC2DMessage)
        }
        
        return azResult
    }
    
    public func GetCommandsSubscribeTopic() -> String
    {
        return AZ_IOT_HUB_CLIENT_COMMANDS_SUBSCRIBE_TOPIC
    }
    
    public func GetCommandsResponseTopic(requestID: String, status: Int16) -> String
    {
        var topicCharArray = [CChar](repeating: 0, count: 100)
        var topicLength : Int = 0
        
        let requestIDSpan = AzSpan(text: requestID)
        
        let _ : az_result = az_iot_hub_client_commands_response_get_publish_topic(&self.embeddedHubClient, requestIDSpan.toCAzSpan(), UInt16(status), &topicCharArray, 100, &topicLength )
        
        return String(cString: topicCharArray)
    }
    
    public func ParseCommandsReceivedTopic(topic: String, message: inout AzureIoTHubCommandRequest) -> az_result
    {
        var embeddedCommandRequest: az_iot_hub_client_command_request = az_iot_hub_client_command_request()

        let topicSpan = AzSpan(text: topic)
        let azResult : az_result = az_iot_hub_client_commands_parse_received_topic(&self.embeddedHubClient, topicSpan.toCAzSpan(), &embeddedCommandRequest)
        
        if az_result_succeeded(azResult)
        {
            message = AzureIoTHubCommandRequest(embeddedCommandRequest: embeddedCommandRequest)
        }
        
        return azResult
    }
    
    public func GetPropertiesResponseSubscribeTopic() -> String
    {
        return AZ_IOT_HUB_CLIENT_PROPERTIES_MESSAGE_SUBSCRIBE_TOPIC
    }
    
    public func GetPropertiesWritablePatchSubscribeTopic() -> String
    {
        return AZ_IOT_HUB_CLIENT_PROPERTIES_WRITABLE_UPDATES_SUBSCRIBE_TOPIC
    }
    
    public func GetPropertiesDocumentPublishTopic(requestID: String) -> String
    {
        var topicCharArray = [CChar](repeating: 0, count: 100)
        var topicLength : Int = 0

        let requestIDSpan = AzSpan(text: requestID)
        
        let _ : az_result = az_iot_hub_client_properties_document_get_publish_topic(&self.embeddedHubClient, requestIDSpan.toCAzSpan(), &topicCharArray, 100, &topicLength )
        
        return String(cString: topicCharArray)
    }
    
    public func GetPropertiesReportedPublishTopic(requestID: String) -> String
    {
        var topicCharArray = [CChar](repeating: 0, count: 100)
        var topicLength : Int = 0

        let requestIDSpan = AzSpan(text: requestID)
        let _ : az_result = az_iot_hub_client_properties_get_reported_publish_topic(&self.embeddedHubClient, requestIDSpan.toCAzSpan(), &topicCharArray, 100, &topicLength)
        
        return String(cString: topicCharArray)
    }
    
    public func ParsePropertiesReceivedTopic(topic: String, message: inout AzureIoTHubPropertiesMessage) -> az_result
    {
        var embeddedPropMessage: az_iot_hub_client_properties_message = az_iot_hub_client_properties_message()

        let topicSpan = AzSpan(text: topic)
        let azResult : az_result = az_iot_hub_client_properties_parse_received_topic(&self.embeddedHubClient, topicSpan.toCAzSpan(), &embeddedPropMessage)
        
        if az_result_succeeded(azResult)
        {
            message = AzureIoTHubPropertiesMessage(embeddedPropertiesMessage: embeddedPropMessage)
        }
        
        return azResult
    }
}

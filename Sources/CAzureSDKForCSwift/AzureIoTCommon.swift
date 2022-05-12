import AzureSDKForCSwift

public var AzureIoTMessagePropertyContentType = AZ_IOT_MESSAGE_PROPERTIES_CONTENT_TYPE

public struct AzureIoTMessageProperties
{
  public var embeddedProperties: az_iot_message_properties = az_iot_message_properties()
  private var embeddedPropertyBuffer = [UInt8](repeating: 0, count: 128)

  public init()
  {
    let embeddedPropertyBufferSpan = AzSpan.init(ptr: &embeddedPropertyBuffer, size: 128)
    let _ : az_result = az_iot_message_properties_init(&embeddedProperties, embeddedPropertyBufferSpan.toCAzSpan(), 0)
  }

  public mutating func appendPropertyAndValue(property: String, value: String)
  {
    let propertySpan = AzSpan.init(text: property)
    let valueSpan = AzSpan.init(text: value)
    let _ : az_result = az_iot_message_properties_append(&self.embeddedProperties, propertySpan.toCAzSpan(), valueSpan.toCAzSpan())
  }
}

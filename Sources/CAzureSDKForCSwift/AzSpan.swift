import Foundation
import AzureIoTUniversalMiddleware

public class AzSpan {
    private var dataPtr: UnsafePointer<UInt8>?
    private var dataSize: Int32

    public init(size: Int32) {
        dataPtr = UnsafePointer<UInt8>(UnsafeMutablePointer<UInt8>.allocate(capacity: Int(size)))
        dataSize = size 
    }

    public init(ptr: UnsafePointer<UInt8>?, size: Int32) {
        dataPtr = ptr
        dataSize = size
    }

    public init(span: az_span) {
        dataPtr = UnsafePointer<UInt8>(az_span_ptr(span))
        dataSize = az_span_size(span)
    }

    public init(data: Data) {
        // TODO: find a way to get a pointer to data bytes instead of copying.
        let result = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: data.count)
        _ = result.initialize(from: data)
        dataPtr = UnsafePointer<UInt8>(result.baseAddress!)

        dataSize = Int32(data.count)
    }

    public init(text: String?) {
        if (text == nil) {
            dataPtr = nil
            dataSize = 0
        } else {
            let utf8 = Array(text!.utf8)
            let result = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: utf8.count)
            _ = result.initialize(from: utf8)

            dataPtr = UnsafePointer<UInt8>(result.baseAddress!)
            if (dataPtr == nil) {
                print("Failed creating AzSpan from String")
            }
            dataSize = Int32(utf8.count)
        }
    }

    public func getPtr() -> UnsafePointer<UInt8>? {
        return dataPtr
    }

    public func getSize() -> Int32 {
        return dataSize
    }

    public func toCAzSpan() -> az_span {
        return az_span_create(UnsafeMutablePointer<UInt8>(mutating: dataPtr), dataSize)
    }

    public func toData() -> Data {
        return dataPtr != nil ? Data(bytes: dataPtr!, count: Int(dataSize)) : Data()
    }

    public func toString() -> String {
        return String(decoding: toData(), as: UTF8.self)
    }

    public func isNullSpan() -> Bool {
        return (dataPtr == nil && dataSize == 0)
    }

    public static func NullAzSpan() -> AzSpan {
        return AzSpan(ptr: nil, size: 0)
    }

    public static func NullCAzSpan() -> az_span {
        return az_span_create(nil, 0)
    }
}


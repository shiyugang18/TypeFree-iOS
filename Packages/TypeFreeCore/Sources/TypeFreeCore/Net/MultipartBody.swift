import Foundation

/// multipart/form-data 构造器。
public struct MultipartBody {
    public let boundary: String
    public private(set) var data: Data

    public init(boundary: String = UUID().uuidString) {
        self.boundary = boundary
        self.data = Data()
    }

    public var contentTypeHeader: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    /// 添加一个文本字段。
    public mutating func addField(name: String, value: String) {
        data.append(Data("--\(boundary)\r\n".utf8))
        data.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
        data.append(Data("\(value)\r\n".utf8))
    }

    /// 添加文件字段。
    public mutating func addFile(name: String, filename: String, contentType: String, fileData: Data) {
        data.append(Data("--\(boundary)\r\n".utf8))
        data.append(Data("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".utf8))
        data.append(Data("Content-Type: \(contentType)\r\n\r\n".utf8))
        data.append(fileData)
        data.append(Data("\r\n".utf8))
    }

    /// 结束报文。
    public mutating func finalize() {
        data.append(Data("--\(boundary)--\r\n".utf8))
    }
}

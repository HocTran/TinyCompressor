//
//  Item.swift
//  Tiny
//
//  Created by HocTran on 7/2/18.
//  Copyright © 2018 Hoc Tran. All rights reserved.
//

import Cocoa

enum ItemStatus {
    case ready
    case loading
    case success(compress: Double?)
    case failed(error: Error)
    
    var color: NSColor {
        switch self {
        case .ready:    return .white
        case .loading:  return .yellow
        case .success:  return .green
        case .failed:   return .red
        }
    }
    
    var title: String {
        switch self {
        case .ready:    return "Ready"
        case .loading:  return "Loading"
        case .success:  return "Success"
        case .failed:   return "Failed"
        }
    }
    
    var remark: String {
        switch self {
        case .ready:    return ""
        case .loading:  return ""
        case .success(let compress):
            if let comp = compress {
                return String(format: "%.1f%%", comp * 100)
            } else {
                return "Unknown compression"
            }
        case .failed(let error):   return error.localizedDescription
        }
    }
    
    var isFinished: Bool {
        if case .success(_) = self {
            return true
        } else if case .failed(_) = self {
            return true
        } else {
            return false
        }
    }
}

class Item {
    var status = ItemStatus.ready
    var fileUrl = URL(fileURLWithPath: "")
    var children: [Item]?
    var parent: Item?
    
    func debug() {
        print(fileUrl)
        children?.forEach {
            print($0.fileUrl)
        }
    }
    
    var isExpandable: Bool {
        return children != nil
    }
    
    static let allowTypes: [String] = [
        "jpg", "JPG", "Jpg",
        "jpeg", "JPEG", "Jpeg",
        "png", "PNG", "Png"
    ]
}

extension Item {
    convenience init(fileUrl: URL, parent: Item?) {
        self.init()
        let fileManager = FileManager.default
        
        self.fileUrl = fileUrl
        self.parent = parent
        
        do {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: fileUrl.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    let urls = try fileManager.contentsOfDirectory(at: fileUrl,
                                                                   includingPropertiesForKeys: nil,
                                                                   options: [.skipsHiddenFiles])
                    self.children = urls.map { Item(fileUrl: $0, parent: self) }
                } else {
                    
                }
            }
        } catch {
            print(error)
        }
    }
    
    ///return all PNG or JPG flattern resursively including self
    func flatImageItems() -> [Item] {
        var result = [Item]()
        if !isExpandable {
            let ext = fileUrl.pathExtension.lowercased()
            if Item.allowTypes.contains(ext) {
                result += [self]
            }
        } else if let children = self.children {
            result += children.flatMap { $0.flatImageItems() }
        } else {
            
        }
        return result
    }
}


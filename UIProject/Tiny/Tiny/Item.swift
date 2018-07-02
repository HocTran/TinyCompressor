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
    case finished(error: Error?)
    
    var color: NSColor {
        switch self {
        case .ready:    return .white
        case .loading:  return .yellow
        case .finished(let error):
            return error == nil ? .green : .red
        }
    }
    
    var title: String {
        switch self {
        case .ready:    return "Ready"
        case .loading:  return "Loading"
        case .finished(let error):
            return error == nil ? "Success" : "Failed"
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
            if ext == "jpg" || ext == "jpeg" || ext == "png" {
                result += [self]
            }
        } else if let children = self.children {
            result += children.flatMap { $0.flatImageItems() }
        } else {
            
        }
        return result
    }
}

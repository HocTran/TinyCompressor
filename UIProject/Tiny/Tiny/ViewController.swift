//
//  ViewController.swift
//  Tiny
//
//  Created by HocTran on 7/2/18.
//  Copyright © 2018 Hoc Tran. All rights reserved.
//

import Cocoa
let Api = "https://api.tinify.com/shrink"

class ViewController: NSViewController {
    
    @IBOutlet weak var outlineView: NSOutlineView!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var progressBar: NSProgressIndicator!
    @IBOutlet weak var openButton: NSButton!
    @IBOutlet weak var startButton: NSButton!
    @IBOutlet weak var keyInputField: NSTextField!
    
//    lazy var session: URLSession {
//        let config = URLSessionConfiguration()
//        config.httpMaximumConnectionsPerHost = 1
//        let session = URLSession(configuration: config)
//        return session
//    }
    
    var rootItem: Item! {
        didSet {
            flatItems = rootItem.flatImageItems()
        }
    }
    
    //item contain PNG or JPG only
    var flatItems = [Item]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        toggleLoading(isOn: false)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @IBAction func openPanel(_ sender: Any?) {
        guard let window = view.window else { return }
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        panel.beginSheetModal(for: window) { (result) in
            if result == .OK {
                let url = panel.urls[0]
                self.rootItem = Item(fileUrl: url, parent: nil)
                self.rootItem.debug()
                self.outlineView.reloadData()
                self.outlineView.expandItem(nil, expandChildren: true)
            }
        }
    }
    
    @IBAction func start(_ sender: Any?) {
        let total = flatItems.count
        if total == 0 {
            return
        }
        
        let apiKey = keyInputField.stringValue
        guard !apiKey.isEmpty else {
            keyInputField.becomeFirstResponder()
            return
        }
        
        toggleLoading(isOn: true)
        
        var count = 0
        self.statusLabel.stringValue = "\(count) / \(total)"
        self.progressBar.doubleValue = 0
        
        flatItems.forEach { item in
            self.updateStatus(.loading, for: item)
            self.processFile(item: item) { (item, compress, error) in
                count += 1
                
                if let err = error {
                    self.updateStatus(.failed(error: err), for: item)
                } else {
                    self.updateStatus(.success(compress: compress), for: item)
                }
                self.statusLabel.stringValue = "\(count) / \(total)"
                self.progressBar.doubleValue = Double(count) / Double(total)
                if count >= total {
                    self.statusLabel.stringValue = "Finished!"
                    self.toggleLoading(isOn: false)
                }
            }
        }
    }
    
    func toggleLoading(isOn: Bool) {
//        progressBar.isHidden = !isOn
//        statusLabel.isHidden = !isOn
        startButton.isEnabled = !isOn
        openButton.isEnabled = !isOn
        keyInputField.isEnabled = !isOn
    }
    
    func updateStatus(_ status: ItemStatus, for item: Item) {
        item.status = status
        let idx = self.outlineView.row(forItem: item)
        if let rowView = self.outlineView.rowView(atRow: idx, makeIfNecessary: false) {
            if item.isExpandable {
                rowView.backgroundColor = NSColor.lightGray.withAlphaComponent(0.2)
            } else {
                rowView.backgroundColor = item.status.color.withAlphaComponent(0.2)
            }
        }
        self.outlineView.reloadItem(item)
    }
}

extension ViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let i = item as? Item {
            return i.children?.count ?? 0
        } else {
            return rootItem == nil ? 0 : 1
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let i = item as? Item {
            return i.children![index]
        } else {
            return rootItem
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let i = item as? Item {
            return i.isExpandable
        }
        return false
    }
}

extension ViewController: NSOutlineViewDelegate {
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if tableColumn?.identifier.rawValue == "File" {
            let view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "NameCell"), owner: nil) as! NSTableCellView
            let textField = view.textField
            if let i = item as? Item {
                textField?.stringValue = i.fileUrl.lastPathComponent
            }
            return view
        } else if tableColumn?.identifier.rawValue == "Status" {
            let view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "StatusCell"), owner: nil) as! NSTableCellView
            let textField = view.textField
            if let i = item as? Item, !i.isExpandable {
                textField?.stringValue = i.status.title
                textField?.textColor = i.status.color
            } else {
                textField?.stringValue = ""
            }
            return view
        } else if tableColumn?.identifier.rawValue == "Mark" {
            let view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "MarkCell"), owner: nil) as! NSTableCellView
            let textField = view.textField
            if let i = item as? Item, !i.isExpandable {
                textField?.stringValue = i.status.remark
                textField?.textColor = i.status.color
            } else {
                textField?.stringValue = ""
            }
            return view
        } else {
            return nil
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, didAdd rowView: NSTableRowView, forRow row: Int) {
        if let item = outlineView.item(atRow: row) as? Item {
            if item.isExpandable {
                rowView.backgroundColor = NSColor.lightGray.withAlphaComponent(0.2)
            } else {
                rowView.backgroundColor = item.status.color.withAlphaComponent(0.2)
            }
        }
    }
    
}

extension ViewController {
    func processFile(item: Item, completion: @escaping (Item, Double, Error?) -> ()) {
        
        let apiKey = keyInputField.stringValue
        let token = "api:\(apiKey)".data(using: .utf8)!
        let authorization = "Basic \(token.base64EncodedString())"
        
        let headers = [
            "authorization": authorization,
            "content-type": "application/x-www-form-urlencoded",
            "cache-control": "no-cache"
        ]
        
        var request = URLRequest(url: URL(string: Api)!,
                                 cachePolicy: .useProtocolCachePolicy,
                                 timeoutInterval: 10.0)
        
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        
        let session = URLSession.shared
        let fileUrl = item.fileUrl
        let uploadTask = session.uploadTask(with: request, fromFile: fileUrl) { (data, response, error) -> Void in
            if let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String : Any], let output = json["output"] as? [String : Any], let resultUrl = output["url"] as? String, let downloadUrl = URL(string: resultUrl) {
                        
                        let downloadTask = session.downloadTask(with: downloadUrl) { (localUrl, reponse, error) in
                            if let localUrl = localUrl {
                                //copy result to original url
                                do {
                                    let _ = try FileManager.default.replaceItemAt(fileUrl, withItemAt: localUrl)
                                    
                                    var compress: Double = 0
                                    if let ratio = output["ratio"] as? Double {
                                        compress = 1 - ratio
                                        print("Finish file: \(fileUrl). Reduced size: \(compress)")
                                        
                                    } else {
                                        print("Finish file: \(fileUrl)")
                                    }
                                    DispatchQueue.main.async {
                                        completion(item, compress, nil)
                                    }
                                    
                                } catch {
                                    print("error while write file: \(fileUrl)")
                                    DispatchQueue.main.async {
                                        completion(item, 0, error)
                                    }
                                }
                            }
                        }
                        downloadTask.resume()
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(item, 0, error)
                    }
                }
                
            } else {
                print("error upload file: \(fileUrl)")
                DispatchQueue.main.async {
                    completion(item, 0, error)
                }
            }
        }
        
        uploadTask.resume()
    }
}

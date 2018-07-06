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
    
    lazy var taskQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 3
        return q
    }()
    
    var items = [Item]() {
        didSet {
            items.forEach {
                $0.debug()
            }
            flatItems = items.flatMap { $0.flatImageItems() }
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
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedFileTypes = Item.allowTypes
        panel.allowsOtherFileTypes = false
        
        panel.beginSheetModal(for: window) { (result) in
            if result == .OK {
                self.items = panel.urls.map { Item(fileUrl: $0, parent: nil) }
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
            let op = ItemOperation(item: item, apiKey: apiKey)
            op.change = { [unowned self] item, status in
                let isFinished = status.isFinished
                
                item.status = status
                DispatchQueue.main.async {
                    self.reload(item: item)
                    if isFinished {
                        count += 1
                        
                        let statusCount = "\(count) / \(total)"
                        let progress = Double(count) / Double(total)
                        let allFinished = count >= total
                        self.statusLabel.stringValue = statusCount
                        self.progressBar.doubleValue = progress
                        if allFinished {
                            self.toggleLoading(isOn: false)
                            self.statusLabel.stringValue = "Finished!"
                        }
                    }
                }
            }
            taskQueue.addOperation(op)
        }
    }
    
    func toggleLoading(isOn: Bool) {
//        progressBar.isHidden = !isOn
//        statusLabel.isHidden = !isOn
        startButton.isEnabled = !isOn
        openButton.isEnabled = !isOn
        keyInputField.isEnabled = !isOn
    }
    
    func reload(item: Item) {
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
            return items.count
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let i = item as? Item {
            return i.children![index]
        } else {
            return items[index]
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

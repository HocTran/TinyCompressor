//
//  Operation.swift
//  Tiny
//
//  Created by HocTran on 7/4/18.
//  Copyright © 2018 Hoc Tran. All rights reserved.
//

import Cocoa

class BaseOperation: Operation {
    private var backing_executing : Bool
    override var isExecuting : Bool {
        get { return backing_executing }
        set {
            willChangeValue(forKey: "isExecuting")
            backing_executing = newValue
            didChangeValue(forKey: "isExecuting")
        }
    }
    
    private var backing_finished : Bool
    override var isFinished : Bool {
        get { return backing_finished }
        set {
            willChangeValue(forKey: "isFinished")
            backing_finished = newValue
            didChangeValue(forKey: "isFinished")
        }
    }
    
    override init() {
        backing_executing = false
        backing_finished = false
        super.init()
    }
    
    func completeOperation() {
        isExecuting = false
        isFinished = true
    }
}

class ItemOperation: BaseOperation {
//    private var _context = 0
    enum Status: String {
        case isReady
        case isCancelled
        case isExecuting
        case isFinished
        
        static var all: [Status] = [.isReady, .isExecuting, .isFinished]
    }
    
    private var item: Item!
    var change:((Item, Status) -> Void)?
    init(item: Item) {
        super.init()
        self.item = item
        Status.all.forEach {
            self.addObserver(self, forKeyPath: $0.rawValue, options: [.initial, .new], context: nil)
        }
    }
    override func start() {
        super.start()
        isExecuting = true
    }
    override func main() {
        if isCancelled {
            completeOperation()
            return
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            self.completeOperation()
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let key = keyPath, let status = Status(rawValue: key), let v = change?[.newKey] as? Bool, v {
            self.change?(item, status)
        }
    }
}

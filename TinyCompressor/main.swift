//
//  main.swift
//  TinyCompressor
//
//  Created by HocTran on 6/15/18.
//  Copyright © 2018 Hoc Tran. All rights reserved.
//

import Foundation

let ApiKey = "HhB1SGxK3y6QnT5TaXiOp-hhnoj6H9-z"
let Api = "https://api.tinify.com/shrink"
let rootDirectory = "/Users/HocTran/Desktop/Assets.xcassets"

let fileManager = FileManager.default

let operationQueue = OperationQueue()
operationQueue.maxConcurrentOperationCount = 3

func processDirectory(at directoryUrl: URL) {
    do {
        let urls = try fileManager.contentsOfDirectory(at: directoryUrl, includingPropertiesForKeys: nil, options: [])
        for url in urls {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    processDirectory(at: url)
                } else if url.pathExtension == "jpg" || url.pathExtension == "jpeg" || url.pathExtension == "png" {
                    processFile(at: url)
                } else {
                    //ignored other file type
                }
            }
        }
    } catch {
        print("error at directory: \(directoryUrl)")
    }
}

///add operation for jpg and png
class CompressOperation: Operation {
    let fileUrl: URL
    private var _executing = false
    private var _finished = false
    
    init(fileUrl: URL) {
        self.fileUrl = fileUrl
        super.init()
    }

    override var isFinished: Bool {
        return _finished
    }
    override var isExecuting: Bool {
        return _executing
    }
    override func start() {
        _executing = true
        _finished = false
        super.start()
    }
    
    override func main() {
//        super.main()
        if isCancelled {
             print("Operation is cancelled before start main")
            return
        }
        let headers = [
            "authorization": "Basic YXBpOkhoQjFTR3hLM3k2UW5UNVRhWGlPcC1oaG5vajZIOS16",
            "content-type": "application/x-www-form-urlencoded",
            "cache-control": "no-cache"
        ]
        
        var request = URLRequest(url: URL(string: Api)!,
                                 cachePolicy: .useProtocolCachePolicy,
                                 timeoutInterval: 10.0)

        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers

        let session = URLSession.shared
        let uploadTask = session.uploadTask(with: request, fromFile: fileUrl) { [weak self] (data, response, error) -> Void in
            guard let sSelf = self else {
                return
            }
            guard sSelf.isExecuting else {
                return
            }

            let fileUrl = sSelf.fileUrl

            if let data = data {

                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String : Any], let output = json["output"] as? [String : Any], let resultUrl = output["url"] as? String, let downloadUrl = URL(string: resultUrl) {

                        let downloadTask = session.downloadTask(with: downloadUrl) { (localUrl, reponse, error) in
                            if let localUrl = localUrl {
                                //copy result to original url
                                do {
                                    let _ = try FileManager.default.replaceItemAt(fileUrl, withItemAt: localUrl)

                                    if let ratio = output["ratio"] as? Double {
                                        print("Finish file: \(fileUrl). Reduced size: \(1 - ratio)")
                                    } else {
                                        print("Finish file: \(fileUrl)")
                                    }
                                } catch {
                                    print("error while write file: \(fileUrl)")
                                }
                            }
                            sSelf.finish()
                        }

                        downloadTask.resume()

                    }
                } catch {
                    sSelf.finish()
                }

            } else {
                print("error upload file: \(fileUrl)")
                sSelf.finish()
            }
        }

        uploadTask.resume()
        
        print("Operation actually finished")
    }
    
    func finish() {
        _finished = true
        _executing = false
    }
}

func processFile(at fileUrl: URL) {
    let op = BlockOperation {
        let headers = [
            "authorization": "Basic YXBpOkhoQjFTR3hLM3k2UW5UNVRhWGlPcC1oaG5vajZIOS16",
            "content-type": "application/x-www-form-urlencoded",
            "cache-control": "no-cache"
        ]
        
        var request = URLRequest(url: URL(string: Api)!,
                                 cachePolicy: .useProtocolCachePolicy,
                                 timeoutInterval: 10.0)
        
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        
        let session = URLSession.shared
        
        let sema = DispatchSemaphore(value: 0);
        let uploadTask = session.uploadTask(with: request, fromFile: fileUrl) { (data, response, error) -> Void in
            if let data = data {
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String : Any], let output = json["output"] as? [String : Any], let resultUrl = output["url"] as? String, let downloadUrl = URL(string: resultUrl) {
                        
                        let downloadTask = session.downloadTask(with: downloadUrl) { (localUrl, reponse, error) in
                            if let localUrl = localUrl {
                                //copy result to original url
                                do {
                                    let _ = try FileManager.default.replaceItemAt(fileUrl, withItemAt: localUrl)
                                    
                                    if let ratio = output["ratio"] as? Double {
                                        print("Finish file: \(fileUrl). Reduced size: \(1 - ratio)")
                                    } else {
                                        print("Finish file: \(fileUrl)")
                                    }
                                } catch {
                                    print("error while write file: \(fileUrl)")
                                }
                            }
                            
                            sema.signal()
                        }
                        
                        downloadTask.resume()
                        
                    }
                } catch {
                    sema.signal()
                }
                
            } else {
                print("error upload file: \(fileUrl)")
                sema.signal()
            }
        }
        
        uploadTask.resume()
        sema.wait()
        
        print("task is finished")
    }
    operationQueue.addOperation(op)
    print("REMAINING: \(operationQueue.operationCount)")
    operationQueue.waitUntilAllOperationsAreFinished()
}


//RUN
func main() {
    let root = URL(string: rootDirectory)!
    processDirectory(at: root)
}

main()

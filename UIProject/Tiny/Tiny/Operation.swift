//
//  Operation.swift
//  Tiny
//
//  Created by HocTran on 7/4/18.
//  Copyright © 2018 Hoc Tran. All rights reserved.
//

import Cocoa

class ItemOperation: Operation {
    private var item: Item!
    private var apiKey: String!
    private var tasks = [URLSessionTask]()
    var change:((Item, ItemStatus) -> Void)?
    
    private var compress: Double?
    private var error: Error?
    
    init(item: Item, apiKey: String) {
        super.init()
        self.item = item
        self.apiKey = apiKey
    }
    
    override func cancel() {
        tasks.forEach {
            $0.cancel()
        }
        super.cancel()
    }
    
    override func main() {
        if isCancelled {
            return
        }
        
        self.change?(self.item, .loading)
        
        /*test ->
        let randomNum = Int(arc4random_uniform(2))
        let mSema = DispatchSemaphore(value: 0)
        DispatchQueue.global().asyncAfter(deadline: .now() + TimeInterval(randomNum)) {
            mSema.signal()
        }
        
        mSema.wait()
        if randomNum % 2 == 0 {
            self.error = NSError(domain: "com.error.test", code: 0, userInfo: nil)
        }
        
        if let error = self.error {
            self.change?(self.item, .failed(error: error))
        } else {
            self.change?(self.item, .success(compress: self.compress))
        }
        
        return
        <- */
        
        let apiKey = self.apiKey!
        let token = "api:\(apiKey)".data(using: .utf8)!
        let authorization = "Basic \(token.base64EncodedString())"
        
        let headers = [
            "authorization": authorization,
            "content-type": "application/x-www-form-urlencoded",
            "cache-control": "no-cache"
        ]
        
        var request = URLRequest(url: URL(string: Api)!,
                                 cachePolicy: .useProtocolCachePolicy,
                                 timeoutInterval: 30.0)
        
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        
        let session = URLSession.shared
        let fileUrl = item.fileUrl
        
        let sema = DispatchSemaphore(value: 0)
        let uploadTask = session.uploadTask(with: request, fromFile: fileUrl) { (data, response, error) -> Void in
            if self.isCancelled {
                return
            }
            
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 401 {
                self.error = NSError(domain: "Unauthorized", code: 401, userInfo: nil)
                sema.signal()
            } else if let error = error {
                self.error = error
                sema.signal()
            } else if let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String : Any] {
                        if let output = json["output"] as? [String : Any], let resultUrl = output["url"] as? String, let downloadUrl = URL(string: resultUrl) {
                            let downloadTask = session.downloadTask(with: downloadUrl) { (localUrl, reponse, error) in
                                if self.isCancelled {
                                    return
                                }
                                
                                if let localUrl = localUrl {
                                    //copy result to original url
                                    do {
                                        let _ = try FileManager.default.replaceItemAt(fileUrl, withItemAt: localUrl)
                                        
                                        var compress: Double?
                                        if let ratio = output["ratio"] as? Double {
                                            compress = 1 - ratio
                                            print("Finish file: \(fileUrl). Reduced size: \(compress!)")
                                            
                                        } else {
                                            print("Finish file: \(fileUrl)")
                                        }
                                        
                                        self.compress = compress
                                        sema.signal()
                                        
                                    } catch {
                                        print("error while write file: \(fileUrl)")
                                        self.error = error
                                        sema.signal()
                                    }
                                }
                            }
                            downloadTask.resume()
                        } else if let msg = json["error"] as? String {
                            self.error = NSError(domain: msg, code: 0, userInfo: nil)
                            sema.signal()
                        } else {
                            self.error = NSError(domain: "unknown error", code: 0, userInfo: nil)
                            sema.signal()
                        }
                    } else {
                        self.error = NSError(domain: "unknown error", code: 0, userInfo: nil)
                        sema.signal()
                    }
                } catch {
                    self.error = error
                    sema.signal()
                }
                
            } else {
                print("error upload file: \(fileUrl)")
                self.error = error
            }
        }
        
        uploadTask.resume()
        sema.wait()
        
        if let error = self.error {
            self.change?(self.item, .failed(error: error))
        } else {
            self.change?(self.item, .success(compress: self.compress))
        }
    }
}

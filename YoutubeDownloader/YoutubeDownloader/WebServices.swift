//
//  WebServices.swift
//  YoutubeDownloader
//
//  Created by Tony Hung on 2/28/15.
//  Copyright (c) 2015 Dark Bear Interactive. All rights reserved.
//

import UIKit

class WebServices: NSObject, NSURLSessionDelegate, NSURLSessionTaskDelegate {
   
    class YoutubeVideo : NSObject,NSCoding {
        var title:String?
        var url:String?
        var thumbnail:String?
        var localURL:String?
        
        func videoDescription() -> String {
            return "title: \(title) url: \(url) thumbnail: \(thumbnail) localURL: \(localURL)"
        }
        init (title: String? = nil, url: String? = nil, thumbnail:String? = nil, localURL:String? = nil) {
            self.title = title
            self.url = url
            self.thumbnail = thumbnail
            self.localURL = localURL
        }
        
        required init?(coder aDecoder: NSCoder) {
            title = aDecoder.decodeObjectForKey("title") as? String
            url = aDecoder.decodeObjectForKey("url") as? String
            thumbnail = aDecoder.decodeObjectForKey("thumbnail") as? String
            localURL = aDecoder.decodeObjectForKey("localURL") as? String

        }
        
        func encodeWithCoder(aCoder: NSCoder) {
            aCoder.encodeObject(title, forKey: "title")
            aCoder.encodeObject(url, forKey: "url")
            aCoder.encodeObject(thumbnail, forKey: "thumbnail")
            aCoder.encodeObject(localURL, forKey: "localURL")

        }

    }
    override init()
    {
        theObject = YoutubeVideo(title: "", url: "", thumbnail: "",localURL: "")
    }
    
    func performSearch(searchTerm:String, completion:(results:[YoutubeVideo], error:NSError?)->Void) {
        
        var videoArray:[YoutubeVideo] = []
        
        var string = "https://gdata.youtube.com/feeds/api/videos?q=\(searchTerm)&max-results=5&alt=json"
        var encodedString = string.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())
        
        
        var request = NSURLRequest (URL: NSURL (string: encodedString!)!)
        print(request.URL)
    
        var session = NSURLSession.sharedSession()
        
        
        func requestCB(data:NSData?,response:NSURLResponse?,error:NSError?){
            print("Response: \(response)")
            
            
            do{
                let strData = NSString(data: data!, encoding: NSUTF8StringEncoding)
                print("Body: \(strData)")
                let json = try NSJSONSerialization.JSONObjectWithData(data!, options: .MutableLeaves) as? NSDictionary
                
                // The JSONObjectWithData constructor didn't return an error. But, we should still
                // check and make sure that json has a value using optional binding.
                if let parseJSON = json {
                    // Okay, the parsedJSON is here, let's get the value for 'success' out of it
                    let success = parseJSON["success"] as? Int
                    print("Succes: \(success)")
                    if let feed:AnyObject = parseJSON["feed"] {
                        let dataArray = feed["entry"] as! NSArray;
                        //println(dataArray)
                        for item in dataArray { // loop through data items
                            let obj = item as! NSDictionary
                            //println(obj)
                            var title:String = ""
                            var thumbnail:String = ""
                            var url:String = "test"
                            
                            if let titleObj:AnyObject = obj["title"] {
                                title = titleObj["$t"] as! String
                            }
                            if let mediaGroup:AnyObject = obj["media$group"] {
                                if let media = mediaGroup["media$thumbnail"] as? NSArray {
                                    //println(media)
                                    if let thumbnailObj = media[0] as? NSDictionary {
                                        thumbnail = thumbnailObj["url"] as! String
                                        //println(youtubeVideo.thumbnail)
                                    }
                                }
                            }
                            
                            if let link = obj["link"]  as? NSArray {
                                //println(media)
                                if let urlObj = link[0] as? NSDictionary {
                                    url = urlObj["href"] as! String
                                }
                            }
                            print("title = \(title) url = \(url) thumbnail = \(thumbnail)")
                            let youtubeVideo:YoutubeVideo = YoutubeVideo(title: title, url: url, thumbnail: thumbnail, localURL:"")
                            videoArray .append(youtubeVideo)
                            
                            
                        }
                        completion(results: videoArray,error:error)
                    }
                }
                
            }catch{
                let jsonStr = NSString(data: data!, encoding: NSUTF8StringEncoding)
                print("Error could not parse JSON: '\(jsonStr)'")
                completion(results: [], error: nil)
            }
        }
        
        let task = session.dataTaskWithRequest(request, completionHandler: requestCB);
        
        task.resume()
        
    }
    typealias CompleteHandlerBlock = () -> ()
    var handlerQueue: [String : CompleteHandlerBlock]!

    var theObject:YoutubeVideo;
    func downloadVideo(url:NSURL, object:YoutubeVideo) {
        
        theObject = object;
        let request:NSURLRequest = NSURLRequest(URL: url)
        let configuration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier("com.darkbearinteractive.youtubedownloder")
        
        let backgroundSession = NSURLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        let downloadTask = backgroundSession.downloadTaskWithRequest(request)
        downloadTask.resume()
         
        
    }
    //MARK: session delegate
    func URLSession(session: NSURLSession, didBecomeInvalidWithError error: NSError?) {
        print("session error: \(error?.localizedDescription).")
    }
    
    func URLSession(session: NSURLSession, didReceiveChallenge challenge: NSURLAuthenticationChallenge, completionHandler: (NSURLSessionAuthChallengeDisposition, NSURLCredential?) -> Void) {
        completionHandler(NSURLSessionAuthChallengeDisposition.UseCredential, NSURLCredential(forTrust: challenge.protectionSpace.serverTrust!))
    }
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        print("session \(session) has finished the download task \(downloadTask) of URL \(location).")
        let fileManger = NSFileManager.defaultManager()
        let paths = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        let documentsURL = paths[0] as NSURL
        
        
        if let title = theObject.title {
            let theTitle =  title.stringByReplacingOccurrencesOfString(" ", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
            let filename = documentsURL .URLByAppendingPathComponent(theTitle).URLByAppendingPathExtension("mp4")
            
            let _:NSError?
            
            print("moving to documents \(filename)")
            
                
            
            do{
                try fileManger.moveItemAtURL(location, toURL: filename)
                
                print("Move successful")
                theObject.localURL = filename.relativePath!
                
                let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as NSString
                let path = paths.stringByAppendingPathComponent("data.plist")
                let fileManager = NSFileManager.defaultManager()
                if (!(fileManager.fileExistsAtPath(path)))
                {
                    let bundle : NSString = NSBundle.mainBundle().pathForResource("data", ofType: "plist")!
                    do{
                    try fileManager.copyItemAtPath(bundle as String, toPath: path)
                    }catch let err as NSError{
                        print(err.localizedDescription)
                    }
                }
                if let array = NSMutableArray(contentsOfFile: path) {
                    array.addObject(theObject)
                    let data = NSKeyedArchiver.archivedDataWithRootObject(array)
                    data.writeToFile(path, atomically: true)
                } else {
                    let array = NSMutableArray()
                    array.addObject(theObject)
                    let data = NSKeyedArchiver.archivedDataWithRootObject(array)
                    data.writeToFile(path, atomically: true)
                }
                
                
            }catch let error as NSError {
                print("Moved failed with error: \(error.localizedDescription)")
            }
        }
    }
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        print("session \(session) download task \(downloadTask) wrote an additional \(bytesWritten) bytes (total \(totalBytesWritten) bytes) out of an expected \(totalBytesExpectedToWrite) bytes.")
    }
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        print("session \(session) download task \(downloadTask) resumed at offset \(fileOffset) bytes out of an expected \(expectedTotalBytes) bytes.")
    }
    
    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        if error == nil {
            print("session \(session) download completed")
        } else {
            print("session \(session) download failed with error \(error?.localizedDescription)")
        }
    }
    
    
    
    func URLSessionDidFinishEventsForBackgroundURLSession(session: NSURLSession) {
        print("background session \(session) finished events.")
        
        if !session.configuration.identifier!.isEmpty {
            callCompletionHandlerForSession(session.configuration.identifier)
        }
    }
    
    //MARK: completion handler
    func addCompletionHandler(handler: CompleteHandlerBlock, identifier: String) {
        handlerQueue[identifier] = handler
    }
    
    func callCompletionHandlerForSession(identifier: String!) {
        let handler : CompleteHandlerBlock = handlerQueue[identifier]!
        handlerQueue!.removeValueForKey(identifier)
        handler()
    }
}


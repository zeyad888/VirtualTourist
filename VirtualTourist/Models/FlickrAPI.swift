//
//  FlickrAPI.swift
//  VirtualTourist
//
//  Created by Zeyad AlHusainan on 26/02/2019.
//  Copyright © 2019 Zeyad. All rights reserved.
//

import Foundation
import CoreData
import UIKit

class FlickerAPI {
    
    static func searchByLatLon(
        latitude: Double?, longitude: Double?, pin: Pin?,
        onComplete: @escaping (_ error: String?, _ done: Bool)
        -> Void
        ) {
        // Defalut boxString
        var boxString = "0,0,0,0"
        
        // get lat,lang
        if let latitude = latitude, let longitude = longitude {
            let minimumLon = max(longitude - Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.0)
            let minimumLat = max(latitude - Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.0)
            let maximumLon = min(longitude + Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.1)
            let maximumLat = min(latitude + Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.1)
            boxString = "\(minimumLon),\(minimumLat),\(maximumLon),\(maximumLat)"
        }
        
        
        let methodParameters = [
            Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
            Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
            Constants.FlickrParameterKeys.BoundingBox: boxString,
            Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,
            Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
            Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
            Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback,
            Constants.FlickrParameterKeys.PerPage: "20"
        ]
        
        // create URL
        var components = URLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        components.queryItems = [URLQueryItem]()
        
        for (key, value) in methodParameters {
            let queryItem = URLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem)
        }
        
        
        // create session and request
        let session = URLSession.shared
        let request = URLRequest(url: components.url!)
        // create network request
        let task = session.dataTask(with: request) { (data, response, error) in
            
            /* GUARD: Was there an error? */
            guard (error == nil) else {
                onComplete(error.debugDescription, false)
                return
                
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                onComplete(error.debugDescription, false)
                return
                
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                onComplete(error.debugDescription, false)
                return
                
            }
            
            // parse the data
            let parsedResult: FlickrJson!
            do {
                parsedResult = try JSONDecoder().decode(FlickrJson.self, from: data)
            } catch {
                onComplete("Error when parse data", false)
                return
                
            }
            /* GUARD: Is "photos" key in our result? */
            guard let photosDictionary = parsedResult.photos else {
                return
            }
            
            /* GUARD: Is "pages" key in the photosDictionary? */
            guard let totalPages = photosDictionary.pages else {
                return
            }
            
            // pick a random page!
            print("We have pages = ", totalPages)
            let pageLimit = min(totalPages, 40)
            let randomPage = Int(arc4random_uniform(UInt32(pageLimit))) + 1
            print("We use page number = ", randomPage)
            self.displayImageFromFlickrBySearch(methodParameters as [String : AnyObject], withPageNumber: randomPage, pin: pin, onComplete: { (error, done) in
                if done {
                    onComplete(nil, true)
                }
                else {
                    onComplete(error, false)
                }
            })
            
            
        }
        
        // start the task!
        task.resume()
}

    private static func flickrURLFromParameters(_ parameters: [String:AnyObject]) -> URL {
        
        var components = URLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        components.queryItems = [URLQueryItem]()
        
        for (key, value) in parameters {
            let queryItem = URLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem)
        }
        
        return components.url!
    }
    
    
    //
    
    private static func displayImageFromFlickrBySearch(_ methodParameters: [String: AnyObject], withPageNumber: Int, pin: Pin?,
                                                       onComplete: @escaping (_ error: String?, _ done: Bool)
        -> Void) {
        
        var dataController = (UIApplication.shared.delegate as! AppDelegate).dataController

        // add the page to the method's parameters
        var methodParametersWithPageNumber = methodParameters
        methodParametersWithPageNumber[Constants.FlickrParameterKeys.Page] = withPageNumber as AnyObject?
        
        // create session and request
        let session = URLSession.shared
        let request = URLRequest(url: flickrURLFromParameters(methodParameters))
        
        // create network request
        let task = session.dataTask(with: request) { (data, response, error) in
            
            // if an error occurs, print it and re-enable the UI
            func displayError(_ error: String) {
                print(error)
                
            }
            
            /* GUARD: Was there an error? */
            guard (error == nil) else {
                onComplete("error: \(error)", false)
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                onComplete("status code is bad)", false)
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                onComplete("No Data", false)
                return
            }
            
            // parse the data
            let parsedResult: [String:AnyObject]!
            do {
                parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
            } catch {
                onComplete("Data error", false)
                return
            }
            
            /* GUARD: Did Flickr return an error (stat != ok)? */
            guard let stat = parsedResult[Constants.FlickrResponseKeys.Status] as? String, stat == Constants.FlickrResponseValues.OKStatus else {
                onComplete("Flickr API returned an error. See error code and message in \(String(describing: parsedResult))", false)
                return
            }
            
            /* GUARD: Is the "photos" key in our result? */
            guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String:AnyObject] else {
                onComplete("Cannot find key '\(Constants.FlickrResponseKeys.Photo)' in \(parsedResult)", false)
                return
            }
            
            /* GUARD: Is the "photo" key in photosDictionary? */
            guard let photosArray = photosDictionary[Constants.FlickrResponseKeys.Photo] as? [[String: AnyObject]] else {
                onComplete("Cannot find key '\(Constants.FlickrResponseKeys.Photo)' in \(photosDictionary)", false)
                return
            }
            
            if photosArray.count == 0 {
                onComplete("No Photos Found. Search Again.", false)
                return
            } else {
                let randomPhotoIndex = Int(arc4random_uniform(UInt32(photosArray.count)))
                let photoDictionary = photosArray[randomPhotoIndex] as [String: AnyObject]
                
                for photo in photosArray {
                    /* GUARD: Does our photo have a key for 'url_m'? */
                    guard let imageUrlString = photo[Constants.FlickrResponseKeys.MediumURL] as? String else {
                        displayError("Cannot find key '\(Constants.FlickrResponseKeys.MediumURL)' in \(photoDictionary)")
                        return
                    }
                    let image = Image(context: dataController.viewContext)
                    image.url = imageUrlString
                    image.pin = pin
                }
                onComplete(nil, true)
                try? dataController.viewContext.save()
                
            }
        }
        
        // start the task!
        task.resume()
    }
    
    //
    
    static func downloadImage( imagePath:String, completionHandler: @escaping (_ imageData: Data?, _ errorString: String?) -> Void){
        let session = URLSession.shared
        let imgURL = NSURL(string: imagePath)
        let request: NSURLRequest = NSURLRequest(url: imgURL! as URL)
        
        let task = session.dataTask(with: request as URLRequest) {data, response, downloadError in
            
            if downloadError != nil {
                completionHandler(nil, "Could not download image \(imagePath)")
            } else {
                
                completionHandler(data, nil)
            }
        }
        
        task.resume()
    }
    
    
    static func loadImage(photo: Photo, onComplete: @escaping (_ error: String?, _ done: Bool, _ data: NSData?)
        -> Void)
    {
        guard (photo.url != nil) else {
            return
        }
        
        do {
            let imgData = try NSData(contentsOf: URL.init(string: photo.url!)!, options: NSData.ReadingOptions())
            onComplete(nil, true, imgData)
        } catch {
            
        }
        
    }
    
    
    
    
    
    struct Constants {
        
        // MARK: Flickr
        struct Flickr {
            static let APIScheme = "https"
            static let APIHost = "api.flickr.com"
            static let APIPath = "/services/rest"
            
            static let SearchBBoxHalfWidth = 1.0
            static let SearchBBoxHalfHeight = 1.0
            static let SearchLatRange = (-90.0, 90.0)
            static let SearchLonRange = (-180.0, 180.0)
        }
        
        // MARK: Flickr Parameter Keys
        struct FlickrParameterKeys {
            static let Method = "method"
            static let APIKey = "api_key"
            static let GalleryID = "gallery_id"
            static let Extras = "extras"
            static let Format = "format"
            static let NoJSONCallback = "nojsoncallback"
            static let SafeSearch = "safe_search"
            static let Text = "text"
            static let BoundingBox = "bbox"
            static let PerPage = "per_page"
            static let Page = "page"
        }
        
        // MARK: Flickr Parameter Values
        struct FlickrParameterValues {
            static let SearchMethod = "flickr.photos.search"
            static let APIKey = "1c1ce36c56c8f38d5016ac5f36894f3b"
            static let ResponseFormat = "json"
            static let DisableJSONCallback = "1" /* 1 means "yes" */
            static let GalleryPhotosMethod = "flickr.galleries.getPhotos"
            static let GalleryID = "5704-72157622566655097"
            static let MediumURL = "url_m"
            static let UseSafeSearch = "1"
        }
        
        // MARK: Flickr Response Keys
        struct FlickrResponseKeys {
            static let Status = "stat"
            static let Photos = "photos"
            static let Photo = "photo"
            static let Title = "title"
            static let MediumURL = "url_m"
            static let Pages = "pages"
            static let Total = "total"
        }
        
        // MARK: Flickr Response Values
        struct FlickrResponseValues {
            static let OKStatus = "ok"
        }
    }
}

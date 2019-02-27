//
//  FlickrJson.swift
//  VirtualTourist
//
//  Created by Zeyad AlHusainan on 26/02/2019.
//  Copyright © 2019 Zeyad. All rights reserved.
//

import Foundation

struct FlickrJson: Codable {
    let photos: Photos?
}

struct Photos: Codable {
    let photo: [Photo]?
    let page: Int?
    let pages: Int?
}

struct Photo: Codable {
    
    let url: String?
    
    enum CodingKeys: String, CodingKey {
        case url = "url_m"
    }
}

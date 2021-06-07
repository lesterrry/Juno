//
//  Axioms.swift
//  Juno
//
//  Created by Lesterrry on 05.06.2021.
//

import Foundation
import Cocoa

class JunoAxioms {
    public static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    
    struct Disk {
        enum Tracks: Equatable {
            case progressive([[URL]])
            case traditional([URL])
        }
        
        let title: String
        let length: Int32
        let coverImage: NSImage?
        let tracks: Tracks
    }
    
    class InfoResponse: Codable {
        let shortMessage: String?
        let shortMessageLink: String?
        let message: String?
        let version: String
        
        enum CodingKeys: String, CodingKey {
            case shortMessage = "short_message"
            case shortMessageLink = "short_message_link"
            case message, version
        }
        
        init(shortMessage: String, shortMessageLink: String, message: String, version: String){
            self.shortMessage = shortMessage
            self.shortMessageLink = shortMessageLink
            self.message = message
            self.version = version
        }
    }
    
}

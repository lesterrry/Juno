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
            
            func array<T>() -> T? {
                if T.self == [URL].self {
                    if case .traditional(let p) = self {
                        return (p as! T)
                    } else {
                        return nil
                    }
                } else if T.self == [[URL]].self {
                    if case .progressive(let p) = self {
                        return (p as! T)
                    } else {
                        return nil
                    }
                }
                return nil
            }
            mutating func append(newElement: [URL]) {
                switch self {
                case .progressive(var p):
                    p.append(newElement)
                    self = .progressive(p)
                case .traditional:
                    fatalError("Attempt to append progressive track item to a traditional collection")
                }
            }
            mutating func append(newElement: URL) {
                switch self {
                case .progressive:
                    fatalError("Attempt to append traditional track item to a progressive collection")
                case .traditional(var t):
                    t.append(newElement)
                    self = .traditional(t)
                }
            }
            mutating func append(newElement: Tracks) {
                switch self {
                case .progressive(var p):
                    switch newElement {
                    case .progressive:
                        fatalError("Attempt to append progressive track item to a progressive collection. Try with a traditional item.")
                    case .traditional(let pNew):
                        p.append(pNew)
                        self = .progressive(p)
                    }
                case .traditional(var t):
                    switch newElement {
                    case .progressive:
                        fatalError("Attempt to append progressive track item to a progressive collection. Try with a traditional item.")
                    case .traditional(let tNew):
                        t.append(contentsOf: tNew)
                        self = .traditional(t)
                    }
                }
            }
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

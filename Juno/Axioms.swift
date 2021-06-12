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
    
    enum SystemState: Equatable {
        case standby, busy, ready, playing, paused
        case error(String?)
    }
    
    enum DiskAnimationState {
        case removed
        case stopped
        case spinning
    }
    
    struct Disk {
        let title: String
        let known: Bool
        let length: String?
        let coverImage: NSImage?
        let fingerprint: String?
        let tracks: Tracks
        
        struct Track: Codable {
            let url: URL?
            var title: String?
            var artist: String?
            var album: String?
            let length: Double?
            
            enum CodingKeys: String, CodingKey {
                case url, title, artist, album, length
            }
            init(url: URL?, title: String?, artist: String?, album: String?, length: Double?) {
                self.url = url
                self.title = title
                self.artist = artist
                self.album = album
                self.length = length
            }
        }
        enum Tracks {
            case progressive([[Track]])
            case traditional([Track])
            
            var progressive: [[Track]]? {
                switch self {
                case .progressive(let p):
                    return p
                case .traditional:
                    return nil
                }
            }
            var traditional: [Track]? {
                switch self {
                case .progressive:
                    return nil
                case .traditional(let t):
                    return t
                }
            }
            
            static func complement(what: [Track], with: [Track]) -> [Track] {
                var complemented: [Track] = what
                for i in what.indices {
                    if what[i].title == nil && with[i].title != nil { complemented[i].title = with[i].title }
                    if what[i].album == nil && with[i].album != nil { complemented[i].album = with[i].album }
                    if what[i].artist == nil && with[i].artist != nil { complemented[i].artist = with[i].artist }
                }
                return complemented
            }
            func count() -> Int {
                switch self {
                case .traditional(let t):
                    return t.count
                case .progressive(let p):
                    return p.count
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
            mutating func append(newElement: Track) {
                switch self {
                case .progressive(var p):
                    p[p.count - 1].append(newElement)
                case .traditional(var t):
                    t.append(newElement)
                    self = .traditional(t)
                }
            }
        }
        
        struct Saved: Codable {
            let reliable: Bool
            let title: String
            let coverImageName: String
            let tracks: [Track]?
            enum CodingKeys: String, CodingKey {
                case reliable, title, tracks
                case coverImageName = "cover_image_name"
            }
            init(reliable: Bool, title: String, coverImageName: String, tracks: [Track]?) {
                self.reliable = reliable
                self.title = title
                self.coverImageName = coverImageName
                self.tracks = tracks
            }
            
            static func fill(_ with: [Track]?) -> [Track]? {
                if with == nil { return nil }
                var t = with
                for i in t!.indices {
                    if t![i].album == nil { t![i].album = "" }
                    if t![i].artist == nil { t![i].artist = "" }
                    if t![i].title == nil { t![i].title = "" }
                }
                return t
            }
        }
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
        
        init(shortMessage: String, shortMessageLink: String, message: String, version: String) {
            self.shortMessage = shortMessage
            self.shortMessageLink = shortMessageLink
            self.message = message
            self.version = version
        }
    }
    
}

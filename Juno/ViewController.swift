//
//  ViewController.swift
//  Juno
//
//  Created by Lesterrry on 05.06.2021.
//

import Cocoa
import AVFoundation
import ID3TagEditor

class ViewController: NSViewController {
    
    //*********************************************************************
    // OUTLETS
    //*********************************************************************
    @IBOutlet weak var diskImageView: NSImageView!
    @IBOutlet weak var mainLabel: NSTextField!
    @IBOutlet weak var additionalLabel: NSTextField!
    
    //*********************************************************************
    // CONSTS
    //*********************************************************************
    let defaults = UserDefaults.standard
    let fm = FileManager.default
    let tagEditor = ID3TagEditor()
    let knownMusicExtensions = ["mp3", "aiff", "flac", "wav", "cdda", "au", "aac", "wma", "ac3", "ape"]
    var dataPath: URL? = nil
    
    //*********************************************************************
    // SYSTEM
    //*********************************************************************
    override func viewDidLoad() {
        super.viewDidLoad()
        //Setting the font programatically
        mainLabel.font = NSFont(name: "Opirus-OPIK", size: 27)
        additionalLabel.font = NSFont(name: "Opirus-OPIK", size: 27)
        
        dataPath = fm.homeDirectoryForCurrentUser.appendingPathComponent("Juno/Disks")
        if !fm.fileExists(atPath: dataPath!.path) {
            try? fm.createDirectory(atPath: dataPath!.path, withIntermediateDirectories: true, attributes: nil)
        }
    }

    override var representedObject: Any? {
        didSet {

        }
    }
    
    override func viewDidAppear() {
        //Fetching data and performing all operations in async mode
//        DispatchQueue.main.async {
//            if let instance = self.fetchInfo() {
//                if JunoAxioms.appVersion != nil && !JunoAxioms.appVersion!.contains("beta") && instance.version != JunoAxioms.appVersion {
//                    if self.displayAlert(
//                        title: "New version is out",
//                        message: "Your current version is \(JunoAxioms.appVersion!), however, \(instance.version) is the latest one.",
//                        buttons: "Update", "Skip"
//                    ) == 1000 {
//                        NSWorkspace.shared.open(URL(string: "https://github.com/Lesterrry/Juno/releases/latest")!)
//                    }
//                }
//                if let m = instance.message, self.defaults.string(forKey: "last_message") != m {
//                    self.displayAlert(title: "Message from the developer", message: m, buttons: "OK")
//                    self.defaults.setValue(m, forKey: "last_message")
//                } else {
//                    self.defaults.setValue("nil", forKey: "last_message")
//                }
//                if let sm = instance.shortMessage {
//                    let appDelegate = NSApplication.shared.delegate as! AppDelegate
//                    appDelegate.initShortMessageMenuItem(title: sm, link: instance.shortMessageLink)
//                }
//            }
//        }
        //Do what every player would do
        
        mainLabel.stringValue = "Reading..."
        DispatchQueue.main.async {
            let disk = self.loadDisk()
            //print(disk)
            self.diskImageView.image = disk?.coverImage
        }
    }

    //*********************************************************************
    // FUNCTIONS
    //*********************************************************************
    @discardableResult
    func loadDisk() -> JunoAxioms.Disk? {
        if let vs = getVolume() {
            var diskTitle = vs.lastPathComponent
            var diskImage: NSImage? = nil
            guard var diskParameters = self.walkThroughPath(path: vs.path) else {
                return nil
            }
            let diskLength = timeString(from: diskParameters.1)
            let fingerprint = self.getFingerprint(from: (diskParameters.0.count(), diskParameters.1))
            
            if let f = fingerprint {
                let path = "\(self.dataPath!.path)/\(f).json"
                if self.fm.fileExists(atPath: path) {
                    if let instance: JunoAxioms.Disk.Saved = try? JSONDecoder().decode(JunoAxioms.Disk.Saved.self, from: FileHandle(forReadingAtPath: path)!.readDataToEndOfFile()), instance.reliable {
                        diskTitle = instance.title
                        if instance.coverImageName != "" {
                            let imagePath = "\(self.dataPath!.path)/\(instance.coverImageName)"
                            if self.fm.fileExists(atPath: imagePath) {
                                print(imagePath)
                                diskImage = NSImage(contentsOfFile: imagePath)!
                            }
                        }
                        if case .traditional = diskParameters.0 {
                            diskParameters.0 = .traditional(JunoAxioms.Disk.Tracks.complement(what: (diskParameters.0.traditional)!, with: instance.tracks!))
                        }
                    }
                } else {
                    let diskToSave = JunoAxioms.Disk.Saved(reliable: false, title: diskTitle, coverImageName: "", tracks: JunoAxioms.Disk.Saved.fill(diskParameters.0.traditional))
                    let jsonData = try? JSONEncoder().encode(diskToSave)
                    self.fm.createFile(atPath: self.dataPath!.appendingPathComponent("\(f).json").path, contents: jsonData, attributes: nil)
                }
            }
            return JunoAxioms.Disk(title: diskTitle, length: diskLength, coverImage: diskImage, fingerprint: fingerprint, tracks: diskParameters.0)
        } else {
            mainLabel.stringValue = "No disc"
            return nil
        }
    }
    
    func walkThroughPath(path: String, recursive: Bool = true) -> (JunoAxioms.Disk.Tracks, Double)? {
        let paths: [String]
        do {
            paths = try fm.contentsOfDirectory(atPath: path)
        } catch {
            return nil
        }

        var tracks = JunoAxioms.Disk.Tracks.traditional([])
        var length: Double = 0.0
        for p in paths {
            do {
                let k = [URLResourceKey.isDirectoryKey, URLResourceKey.isHiddenKey] as Set<URLResourceKey>
                var b = URL(fileURLWithPath: path)
                b.appendPathComponent(p, isDirectory: false)
                let a = try b.resourceValues(forKeys: k)
                if (a.isDirectory ?? false) && recursive {
                    if case .traditional = tracks { tracks = .progressive([])}
                    guard let folderData = walkThroughPath(path: b.path, recursive: false) else {
                        return nil
                    }
                    tracks.append(newElement: folderData.0)
                    length += folderData.1
                } else if !(a.isHidden ?? true) && knownMusicExtensions.contains(b.pathExtension) {
                    let track = JunoAxioms.Disk.Track(url: b.absoluteURL, title: nil, artist: nil, album: nil)
                    tracks.append(newElement: track)
                    let asset = AVURLAsset(url: b, options: nil)
                    length += asset.duration.seconds
                }
            } catch {
                mainLabel.stringValue = "Disc error"
                return nil
            }
        }
        return (tracks, length)
    }
    
    
    func getFingerprint(from: (Int?, Double?)) -> String? {
        if let a = from.0, let b = from.1 {
            return "\(a)*\(String(format: "%.3f", b).replacingOccurrences(of: ".", with: ","))"
        }
        return nil
    }
    
    func getVolume() -> URL? {
        let keys = [URLResourceKey.nameKey, URLResourceKey.volumeIsRemovableKey, URLResourceKey.nameKey, URLResourceKey.volumeAvailableCapacityKey] as Set<URLResourceKey>
        let paths = fm.mountedVolumeURLs(includingResourceValuesForKeys: .none, options: .skipHiddenVolumes)
        if paths == nil { return nil }
        for path in paths!{
            if try! path.resourceValues(forKeys: keys).volumeAvailableCapacity == 0 {
                return path.absoluteURL
            }
        }
        return nil
    }
    
    func spinDisk() {
        let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotateAnimation.fromValue = 0.0
        rotateAnimation.byValue = Double.pi * -2.0
        rotateAnimation.duration = 1
        rotateAnimation.repeatCount = .infinity
        diskImageView.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        diskImageView.layer?.position = CGPoint(x: diskImageView.frame.origin.x + diskImageView.frame.width / 2,
                                             y: diskImageView.frame.origin.y + diskImageView.frame.height / 2)
        diskImageView.layer?.add(rotateAnimation, forKey: nil)
        diskImageView.layer?.borderWidth = 1
        diskImageView.layer?.masksToBounds = true
        diskImageView.layer?.cornerRadius = diskImageView.frame.height / 2 //This will change with corners of image and height/2 will make this circle shape
    }
    
    func fetchInfo() -> JunoAxioms.InfoResponse? {
        var instance: JunoAxioms.InfoResponse? = nil
        let semaphore = DispatchSemaphore(value: 0)
        let session = URLSession.shared
        let url = URL(string: JunoKeys.infoEndpoint + JunoKeys.infoKey)!
        let task = session.dataTask(with: url, completionHandler: { data, response, error in
            if error != nil { return }
            instance = try? JSONDecoder().decode(JunoAxioms.InfoResponse.self, from: data!)
            semaphore.signal()
        })
        task.resume()
        semaphore.wait()
        return instance
    }
    
    func timeString(from: Double) -> String? {
        let a = Int(from)
        let b = a / 60
        let c = a % 60
        return "\(b):\(c < 10 ? "0": "")\(c)"
    }
    
    func getCoverFromID3(from: JunoAxioms.Disk.Tracks, attemps: Int = 3) -> NSImage? {
        var tracks: [JunoAxioms.Disk.Track] = []
        switch from {
        case .progressive(let p):
            for i in p {
                tracks.append(contentsOf: i)
            }
        case .traditional(let t):
            tracks = t
        }
        for i in 0...attemps - 1 {
            if let tag = try? tagEditor.read(from: tracks[i].url!.path) {
                if let image = tag.frames[.attachedPicture(.frontCover)] as? ID3FrameAttachedPicture {
                    return NSImage(data: image.picture)
                }
            }
        }
        return nil
    }
    
    @discardableResult
    func shell(_ args: String...) -> Int32 {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = args
        task.launch()
        task.waitUntilExit()
        return task.terminationStatus
    }
    
    @discardableResult
    func displayAlert(title: String, message: String, buttons: String...) -> Int {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        for button in buttons{
            alert.addButton(withTitle: button)
        }
        return alert.runModal().rawValue
    }
}


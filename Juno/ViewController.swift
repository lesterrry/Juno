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
    @IBOutlet weak var numberLabel: NSTextField!
    @IBOutlet weak var knownLightImageView: NSImageView!
    @IBOutlet weak var folderIcoLightImageView: NSImageView!
    @IBOutlet weak var trackIcoLightImageView: NSImageView!
    @IBOutlet weak var diskLoadOneImageView: NSImageView!
    @IBOutlet weak var diskLoadTwoImageView: NSImageView!
    @IBOutlet weak var diskLoadThreeImageView: NSImageView!
    @IBAction func nextButtonPressed(_ sender: Any) { move(true) }
    @IBAction func previousButtonPressed(_ sender: Any) { move(false) }
    @IBAction func playPauseButtonPressed(_ sender: Any) { playPause() }
    
    //*********************************************************************
    // CONSTS & VARS
    //*********************************************************************
    let defaults = UserDefaults.standard
    let fm = FileManager.default
    let tagEditor = ID3TagEditor()
    let knownMusicExtensions = ["mp3", "aiff", "flac", "wav", "cdda", "au", "aac", "wma", "ac3", "ape"]
    let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation")
    
    var player = AVAudioPlayer()
    var diskLoadLightPosition = 0
    var displayLabelType = 0
    var mainTimer: Timer!
    var dataPath: URL? = nil
    var systemCurrentState = JunoAxioms.SystemState.standby
    var systemTargetState: JunoAxioms.SystemState? = nil
    var diskAnimationCurrentState = JunoAxioms.DiskAnimationState.removed
    var diskAnimationTargetState: JunoAxioms.DiskAnimationState? = nil
    var diskAnimationReady = true
    var mainDisk: JunoAxioms.Disk? = nil
    var currentTrack: JunoAxioms.Disk.Track? = nil
    var currentPlaybackIndex = 0
    var currentFolderIndex = 0
    
    //*********************************************************************
    // MAIN SYSTEM
    //*********************************************************************
    override func viewDidLoad() {
        super.viewDidLoad()
        //Setting the font programatically
        mainLabel.font = NSFont(name: "MinecartLCD", size: 23)
        additionalLabel.font = NSFont(name: "MinecartLCD", size: 23)
        numberLabel.font = NSFont(name: "DS-Digital", size: 32)
        
        mainTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.mainTick), userInfo: nil, repeats: true)
        
        dataPath = fm.homeDirectoryForCurrentUser.appendingPathComponent("Music/Juno/Disks")
        if !fm.fileExists(atPath: dataPath!.path) {
            try? fm.createDirectory(atPath: dataPath!.path, withIntermediateDirectories: true, attributes: nil)
        }
    }

    override var representedObject: Any? {
        didSet {

        }
    }
    
    override func viewDidAppear() {
        //Fetch data and performing all operations in async mode
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
        //Setting up disk animation view
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.diskImageView.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            self.diskImageView.layer?.position = CGPoint(x: self.diskImageView.frame.origin.x + self.diskImageView.frame.width / 2,
                                                         y: self.diskImageView.frame.origin.y + self.diskImageView.frame.height / 2)
            self.diskImageView.layer?.borderWidth = 1
            self.diskImageView.layer?.masksToBounds = true
            self.diskImageView.layer?.cornerRadius = self.diskImageView.frame.height / 2
        }
        
        //Reading the disk
        setSystemCurrentState(.busy)
        mainLabel.stringValue = "READING..."
        DispatchQueue.global(qos: .background).async {
            guard let disk = self.loadDisk() else {
                self.systemTargetState = .error("NO DISK")
                return
            }
            self.mainDisk = disk
        }
    }

    //*********************************************************************
    // FUNCTIONS
    //*********************************************************************
    func move(_ towards: Bool) {
        switch systemCurrentState {
        case .playing, .ready, .paused:
            var c = 0
            var length = "??"
            switch mainDisk!.tracks {
            case .traditional(let t): c = t.count - 1
            case .progressive(let p): c = p[currentFolderIndex].count - 1
            }
            if currentPlaybackIndex < c && towards {
                currentPlaybackIndex += 1
            } else if currentPlaybackIndex > 0 && !towards {
                currentPlaybackIndex -= 1
            } else {
                currentPlaybackIndex = towards ? 0 : c
            }
            
            numberLabel.stringValue = String(currentPlaybackIndex + 1)
            switch mainDisk!.tracks {
            case .traditional(let t): length = timeString(from: t[currentPlaybackIndex].length ?? 0.0) ?? "??"
            case .progressive(let p): length = timeString(from: p[currentFolderIndex][currentPlaybackIndex].length ?? 0.0) ?? "??"
            }
            additionalLabel.stringValue = length
            
            if systemCurrentState == .playing {
                playPause(force: true)
            }
        default: ()
        }
    }
    func playPause(force: Bool? = nil) {
        if (force != nil && force!) || systemCurrentState == .ready {
            var track: JunoAxioms.Disk.Track? = nil
            switch mainDisk!.tracks {
            case .progressive(let p):
                track = p[currentFolderIndex][currentPlaybackIndex]
            case .traditional(let t):
                track = t[currentPlaybackIndex]
            }
            guard track != nil && track!.url != nil else {
                setSystemCurrentState(.error("File error"))
                return
            }
            do {
                try player = AVAudioPlayer(contentsOf: track!.url!)
            } catch {
                setSystemCurrentState(.error("Player error"))
                return
            }
            player.play()
            setSystemCurrentState(.playing)
            diskAnimationTargetState = .spinning
            currentTrack = track
        }
    }
    
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
            var known = false
            
            if let f = fingerprint {
                let path = "\(self.dataPath!.path)/\(f).json"
                if self.fm.fileExists(atPath: path) {
                    if let instance: JunoAxioms.Disk.Saved = try? JSONDecoder().decode(JunoAxioms.Disk.Saved.self, from: FileHandle(forReadingAtPath: path)!.readDataToEndOfFile()), instance.reliable {
                        diskTitle = instance.title
                        known = true
                        if instance.coverImageName != "" {
                            let imagePath = "\(self.dataPath!.path)/\(instance.coverImageName)"
                            if self.fm.fileExists(atPath: imagePath) {
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
            if diskImage == nil {
                diskImage = getCoverFromID3(from: diskParameters.0)
            }
            return JunoAxioms.Disk(title: diskTitle, known: known, length: diskLength, coverImage: diskImage, fingerprint: fingerprint, tracks: diskParameters.0)
        } else {
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
                    let asset = AVURLAsset(url: b, options: nil)
                    let c = asset.duration.seconds
                    length += c
                    let track = JunoAxioms.Disk.Track(url: b.absoluteURL, title: nil, artist: nil, album: nil, length: c)
                    tracks.append(newElement: track)
                }
            } catch {
                return nil
            }
        }
        return (tracks, length)
    }
    
    func setSystemCurrentState(_ to: JunoAxioms.SystemState) {
        systemCurrentState = to
        switch to {
        case .error(let e):
            if e != nil { mainLabel.stringValue = e! }
            lightsOut()
        case .ready:
            diskLoadOneImageView.isHidden = false
            diskLoadTwoImageView.isHidden = false
            diskLoadThreeImageView.isHidden = false
        default: ()
        }
    }
    
    func lightsOut() {
        trackIcoLightImageView.isHidden = true
        folderIcoLightImageView.isHidden = true
        knownLightImageView.isHidden = true
        diskLoadOneImageView.isHidden = true
        diskLoadTwoImageView.isHidden = true
        diskLoadThreeImageView.isHidden = true
    }
    
    func displayToComply(with: JunoAxioms.Disk) {
        switch with.tracks {
        case .progressive(let p):
            folderIcoLightImageView.isHidden = false
            trackIcoLightImageView.isHidden = true
            numberLabel.stringValue = String(p.count)
        case .traditional(let t):
            folderIcoLightImageView.isHidden = true
            trackIcoLightImageView.isHidden = false
            numberLabel.stringValue = String(t.count)
        }
        additionalLabel.stringValue = with.length ?? ""
        mainLabel.stringValue = with.title
        knownLightImageView.isHidden = !with.known
    }
    
    func diskAnimationToComply(with: JunoAxioms.DiskAnimationState) {
        diskAnimationReady = false
        let complete = {
            self.diskAnimationReady = true
            self.diskAnimationCurrentState = with
        }
        let driveAnimation = { (completion: @escaping () -> (), offset: Int) in
            CATransaction.begin()
            CATransaction.setCompletionBlock {
                completion()
            }
            let animation = CABasicAnimation(keyPath: "position.y")
            animation.byValue = -100 * offset
            animation.duration = 1.0
            animation.isRemovedOnCompletion = false
            animation.fillMode = .both
            self.diskImageView.layer?.add(animation, forKey: nil)
            CATransaction.commit()
        }
        
        switch with {
        case .spinning:
            let todo = {
                CATransaction.begin()
                CATransaction.setCompletionBlock {
                    self.rotateAnimation.timingFunction = .none
                    self.rotateAnimation.repeatCount = .infinity
                    self.diskImageView.layer?.removeAnimation(forKey: "rotation")
                    self.diskImageView.layer?.add(self.rotateAnimation, forKey: "rotation")
                    complete()
                }
                self.rotateAnimation.fromValue = 0.0
                self.rotateAnimation.byValue = Double.pi * -2.0
                self.rotateAnimation.duration = 1
                self.rotateAnimation.timingFunction = CAMediaTimingFunction(name: .easeIn)
                self.rotateAnimation.isRemovedOnCompletion = true
                self.diskImageView.layer?.add(self.rotateAnimation, forKey: "rotation")
                CATransaction.commit()
            }
            if diskAnimationCurrentState == .removed {
                driveAnimation(todo, 1)
            } else {
                todo()
            }
        case .stopped:
            if diskAnimationCurrentState == .removed {
                driveAnimation(complete, 1)
            } else {
                diskImageView.layer?.removeAnimation(forKey: "rotation")
                complete()
            }
        case .removed:
            diskImageView.layer?.removeAnimation(forKey: "rotation")
            driveAnimation(complete, -1)
        }
        diskAnimationCurrentState = with
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
    
    @objc
    func mainTick() {
        if systemTargetState != nil {
            let a = systemTargetState
            systemTargetState = nil
            setSystemCurrentState(a!)
            return
        }
        if diskAnimationTargetState != nil && diskAnimationTargetState != diskAnimationCurrentState && diskAnimationReady {
            diskAnimationToComply(with: diskAnimationTargetState!)
            diskAnimationTargetState = nil
        }
        switch systemCurrentState {
        case let k where k == .busy || k == .playing:
            if k == .busy {
                if mainDisk != nil {
                    self.displayToComply(with: mainDisk!)
                    if mainDisk!.coverImage != nil { self.diskImageView.image = mainDisk!.coverImage }
                    diskAnimationTargetState = .stopped
                    self.setSystemCurrentState(.ready)
                    return
                }
            } else {
                displayLabelType += 1
                guard currentTrack != nil else {
                    return
                }
                switch displayLabelType {
                case 3: // Title
                    mainLabel.stringValue = currentTrack!.title ?? "Track \(currentPlaybackIndex)"
                case 6: // Artist
                    mainLabel.stringValue = "By \(currentTrack!.artist ?? "unknown")"
                case 9: // Album
                    mainLabel.stringValue = currentTrack!.album ?? "Album unknown"
                    displayLabelType = 0
                default: ()
                }
                additionalLabel.stringValue = timeString(from: player.currentTime.distance(to: currentTrack!.length!)) ?? "Playing"
            }
            diskLoadLightPosition += 1
            switch diskLoadLightPosition {
            case 1:
                diskLoadOneImageView.isHidden = false
                diskLoadTwoImageView.isHidden = true
                diskLoadThreeImageView.isHidden = true
            case 2:
                diskLoadOneImageView.isHidden = true
                diskLoadTwoImageView.isHidden = false
                diskLoadThreeImageView.isHidden = true
            case 3:
                diskLoadOneImageView.isHidden = true
                diskLoadTwoImageView.isHidden = true
                diskLoadThreeImageView.isHidden = false
                diskLoadLightPosition = 0
            default: ()
            }
        default: ()
        }
    }
}


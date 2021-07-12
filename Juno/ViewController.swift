//
//  ViewController.swift
//  Juno
//
//  Created by Lesterrry on 05.06.2021.
//

import Cocoa
import AVFoundation
import ID3TagEditor
import MediaPlayer

class MainView: NSView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        return true
    }
    override var acceptsFirstResponder : Bool {
        return true
    }
}

class ViewController: NSViewController, AVAudioPlayerDelegate {
    
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
    @IBOutlet weak var mp3LightImageView: NSImageView!
    @IBOutlet weak var hiResLightImageView: NSImageView!
    @IBOutlet weak var folderLightImageView: NSImageView!
    @IBOutlet weak var allLightImageView: NSImageView!
    @IBOutlet weak var oneLightImageView: NSImageView!
    @IBOutlet weak var repeatLightImageView: NSImageView!
    @IBOutlet weak var shuffleLightImageView: NSImageView!
    @IBOutlet weak var levelIndicator: NSLevelIndicator!
    @IBAction func nextButtonPressed(_ sender: NSClickGestureRecognizer) { move(true); playSFX("Button") }
    @IBAction func previousButtonPressed(_ sender: NSClickGestureRecognizer) { move(false); playSFX("Button") }
    @IBAction func playPauseButtonPressed(_ sender: Any) { playPause() }
    @IBAction func nextButtonHeld(_ sender: NSPressGestureRecognizer) {
        if sender.state == .began { ffdrew = true; playSFX("ButtonHold") } else if sender.state != .changed { ffdrew = nil; playSFX("ButtonRelease") }
    }
    @IBAction func previousButtonHeld(_ sender: NSPressGestureRecognizer) {
        if sender.state == .began { ffdrew = false; playSFX("ButtonHold") } else if sender.state != .changed { ffdrew = nil; playSFX("ButtonRelease") }
    }
    @IBAction func stopEjectButtonPressed(_ sender: Any) { stopEject() }
    @IBAction func modeButtonPressed(_ sender: Any) { switchPlaybackMode() }
    @IBAction func nextFolderButtonPressed(_ sender: Any) { changeFolder(true) }
    @IBAction func previousFolderButtonPressed(_ sender: Any) { changeFolder(false) }
    @IBAction func setFolderButtonPressed(_ sender: Any) { handleSet() }
    
    //*********************************************************************
    // CONSTS & VARS
    //*********************************************************************
    let defaults = UserDefaults.standard
    let controlCenter = MPRemoteCommandCenter.shared()
    let controlCenterInfo = MPNowPlayingInfoCenter.default()
    let fm = FileManager.default
    let tagEditor = ID3TagEditor()
    let knownBasicExtensions = ["mp3", "aac", "wma", "ogg"]
    let knownHiResExtensions = ["wav", "aiff", "dsd", "flac", "alac", "mqa"]
    let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation")
    
    var setupMenu: JunoMenu!
    var playbackMode = JunoAxioms.PlaybackMode.direct
    var player = AVAudioPlayer()
    var SFXplayer = AVAudioPlayer()
    var diskLoadLightPosition = 0
    var displayLabelType = 0
    var mainTimer: Timer!
    var levelIndicatorUpdateTimer: Timer!
    var dataPath: URL? = nil
    var systemCurrentState = JunoAxioms.SystemState.standby
    var systemTargetState: JunoAxioms.SystemState? = nil
    var diskAnimationCurrentState = JunoAxioms.DiskAnimationState.removed
    var diskAnimationTargetState: JunoAxioms.DiskAnimationState? = nil
    var diskAnimationReady = true
    var mainDisk: JunoAxioms.Disk? = nil
    var currentTrack: JunoAxioms.Disk.Track? = nil
    var cachedTracks: JunoAxioms.Disk.Tracks? = nil
    var ffdrew: Bool? = nil
    var currentPlaybackIndex = 0
    var playbackIndexChanged = false
    var cachedPlaybackIndex: Int? = nil
    var currentFolderIndex = 0
    
    //*********************************************************************
    // MAIN SYSTEM
    //*********************************************************************
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard let disk = mainDisk else {
            return
        }
        if playbackMode != .repeatOne {
            switch disk.tracks {
            case .progressive(let p):
                let c = p[currentFolderIndex].count
                if c == currentPlaybackIndex + 1 { // If the folder ended
                    if p.count == currentFolderIndex + 1 { // If the folder is the last one
                        if playbackMode == .repeatAll { changeFolder(true) } else { stopEject() } // Start the disk over if needed; stop otherwise
                    } else {
                        if playbackMode == .repeatFolder { currentPlaybackIndex = 0; playPause(force: true) } else { changeFolder(true) } // Start the folder over if needed; continue otherwise
                    }
                } else {
                    move(true)
                }
            case .traditional(let t):
                if t.count == currentPlaybackIndex + 1 { // If the disk ended
                    if playbackMode == .repeatAll { move(true) } else { stopEject() } // Start over if needed; stop otherwise
                } else {
                    move(true) // Next track
                }
            }
        } else {
            playPause(force: true)
        }
    }
    
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
        setupMenu = JunoMenu(
            JunoMenu.Setting(title: "USE ID3", key: "use_id3", values: ["NO", "YES"], index: defaults.integer(forKey: "use_id3")),
            JunoMenu.Setting(title: "AUTOLAUNCH", key: "autolaunch", values: ["DISABLE", "ENABLE"], index: defaults.integer(forKey: "autolaunch"))
        )
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            self.myKeyDown(with: $0)
            return nil
        }
        controlCenter.togglePlayPauseCommand.addTarget{_ in
            if self.systemCurrentState == .ready || self.systemCurrentState == .paused || self.systemCurrentState == .playing {
                self.playPause()
                return .success
            }
            return .commandFailed
        }
        controlCenter.playCommand.addTarget {_ in
            if self.systemCurrentState == .ready || self.systemCurrentState == .paused {
                self.playPause()
                return .success
            }
            return .commandFailed
        }
        controlCenter.pauseCommand.addTarget {_ in
            if self.systemCurrentState == .playing {
                self.playPause()
                return .success
            }
            return .commandFailed
        }
        controlCenter.nextTrackCommand.addTarget {_ in
            if self.systemCurrentState == .playing {
                self.move(true)
                return .success
            }
            return .commandFailed
        }
        controlCenter.previousTrackCommand.addTarget {_ in
            if self.systemCurrentState == .playing {
                self.move(false)
                return .success
            }
            return .commandFailed
        }
        controlCenter.seekForwardCommand.addTarget {_ in
            return .commandFailed
        }
        controlCenter.seekBackwardCommand.addTarget {_ in
            return .commandFailed
        }
        controlCenter.changePlaybackPositionCommand.addTarget {_ in
            if self.controlCenterInfo.nowPlayingInfo != nil {
                self.controlCenterInfo.nowPlayingInfo!["MPNowPlayingInfoPropertyElapsedPlaybackTime"] = self.player.currentTime
            }
            return .commandFailed
        }
    }
    
    override func viewDidAppear() {
        // Fetching data and performing all operations in async mode
        DispatchQueue.main.async {
            if let instance = self.fetchInfo() {
                if JunoAxioms.appVersion != nil && !JunoAxioms.appVersion!.contains("beta") && instance.version != JunoAxioms.appVersion {
                    if self.displayAlert(
                        title: "New version is out",
                        message: "Your current version is \(JunoAxioms.appVersion!), however, \(instance.version) is the latest one.",
                        buttons: "Update", "Skip"
                    ) == 1000 {
                        NSWorkspace.shared.open(URL(string: "https://github.com/Lesterrry/Juno/releases/latest")!)
                    }
                }
                if let m = instance.message, self.defaults.string(forKey: "last_message") != m {
                    self.displayAlert(title: "Message from the developer", message: m, buttons: "OK")
                    self.defaults.setValue(m, forKey: "last_message")
                } else {
                    self.defaults.setValue("nil", forKey: "last_message")
                }
                if let sm = instance.shortMessage {
                    let appDelegate = NSApplication.shared.delegate as! AppDelegate
                    appDelegate.initShortMessageMenuItem(title: sm, link: instance.shortMessageLink)
                }
            }
        }
        // Setting up disk animation view
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.diskImageView.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            self.diskImageView.layer?.position = CGPoint(x: self.diskImageView.frame.origin.x + self.diskImageView.frame.width / 2,
                                                         y: self.diskImageView.frame.origin.y + self.diskImageView.frame.height / 2)
            self.diskImageView.layer?.borderWidth = 1
            self.diskImageView.layer?.masksToBounds = true
            self.diskImageView.layer?.cornerRadius = self.diskImageView.frame.height / 2
        }
        
        // Reading the disk if needed
        if defaults.integer(forKey: "autolaunch") == 1 { prepareDisk() }
    }

    //*********************************************************************
    // FUNCTIONS
    //*********************************************************************
    func myKeyDown(with event: NSEvent) {
        super.keyDown(with: event)
        switch event.keyCode {
        case 12:
            exit(0)
        case 0:
            switchPlaybackMode()
        case 1:
            stopEject()
        case 36:
            handleSet()
        case 49:
            playPause()
        case 123:
            move(false)
        case 124:
            move(true)
        case 125:
            changeFolder(false)
        case 126:
            changeFolder(true)
        default: ()
        }
    }
    
    func handleSet() {
        guard systemCurrentState == .ready else { return }
        if !setupMenu.invoked {
            lightsOut()
            displayToComply(with: setupMenu.invoke())
        } else {
            for i in setupMenu.settings {
                defaults.setValue(i.index, forKey: i.key)
                print("\(i.key) = \(i.index)")
            }
            setupMenu.hide()
            displayToComply(with: mainDisk!, includeDiskLoadLightReset: true)
        }
    }
    
    func move(_ towards: Bool) {
        if setupMenu.invoked {
            displayToComply(with: setupMenu.moveValue(towards ? .up : .down))
            return
        }
        switch systemCurrentState {
        case .playing, .ready, .paused:
            var c = 0
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
            case .traditional(let t):
                let tr = t[currentPlaybackIndex]
                additionalLabel.stringValue = timeString(from: tr.length ?? 0.0) ?? "??"
                if let ti = tr.title { mainLabel.stringValue = ti }
            case .progressive(let p):
                let tr = p[currentFolderIndex][currentPlaybackIndex]
                additionalLabel.stringValue = timeString(from: tr.length ?? 0.0) ?? "??"
                if let ti = tr.title { mainLabel.stringValue = ti }
                trackIcoLightImageView.isHidden = false
                folderIcoLightImageView.isHidden = true
            }
            if systemCurrentState == .playing {
                playPause(force: true)
            } else if systemCurrentState == .paused {
                playbackIndexChanged = true
            }
        default: ()
        }
    }
    
    func changeFolder(_ towards: Bool) {
        if setupMenu.invoked {
            displayToComply(with: setupMenu.moveSetting(towards ? .up : .down))
            return
        }
        switch systemCurrentState {
        case .playing, .ready, .paused:
            var c = 0
            var name = ""
            switch mainDisk!.tracks {
            case .traditional: return
            case .progressive(let p): c = p.count - 1
            }
            if currentFolderIndex < c && towards {
                currentFolderIndex += 1
            } else if currentFolderIndex > 0 && !towards {
                currentFolderIndex -= 1
            } else {
                currentFolderIndex = towards ? 0 : c
            }
            if case .progressive(let p) = mainDisk!.tracks {
                name = p[currentFolderIndex][0].url?.deletingLastPathComponent().lastPathComponent ?? "No name"
            }
            currentPlaybackIndex = 0
            numberLabel.stringValue = String(currentFolderIndex + 1)
            additionalLabel.stringValue = name
            trackIcoLightImageView.isHidden = true
            folderIcoLightImageView.isHidden = false
            if systemCurrentState == .playing {
                playPause(force: true)
            } else if systemCurrentState == .paused {
                playbackIndexChanged = true
            }
        default: ()
        }
    }
    
    func stopEject() {
        player = AVAudioPlayer()
        setupMenu.hide()
        switch systemCurrentState {
        case .playing, .paused:
            lightsOut()
            displayToComply(with: mainDisk!)
            setSystemCurrentState(.ready)
            diskAnimationTargetState = .stopped
            currentTrack = nil
            currentPlaybackIndex = 0
            currentFolderIndex = 0
        case .ready:
            lightsOut(withText: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { self.shell("drutil eject") }
            setSystemCurrentState(.standby)
            diskAnimationTargetState = .removed
        case .standby:
            shell("drutil tray eject")
        case .error:
            lightsOut(withText: true)
            setSystemCurrentState(.standby)
        default: ()
        }
    }
    
    func playPause(force: Bool? = nil) {
        setupMenu.hide()
        if (force != nil && force!) || systemCurrentState == .ready {
            setSystemCurrentState(.playing)
            mainLabel.stringValue = "READING"
            numberLabel.stringValue = String(currentPlaybackIndex + 1)
            DispatchQueue.global(qos: .background).async { [self] in
                displayLabelType = 0
                var track: JunoAxioms.Disk.Track? = nil
                switch mainDisk!.tracks {
                case .progressive(let p):
                    track = p[currentFolderIndex][currentPlaybackIndex]
                    if track!.title == nil || track!.artist == nil || track!.album == nil {
                        if defaults.integer(forKey: "use_id3") == 1, let tag = try? tagEditor.read(from: track!.url!.path) {
                            track!.title = (tag.frames[.title] as? ID3FrameWithStringContent)?.content
                            track!.artist = (tag.frames[.artist] as? ID3FrameWithStringContent)?.content
                            track!.album = (tag.frames[.album] as? ID3FrameWithStringContent)?.content
                        } else {
                            track!.title = track!.url?.lastPathComponent
                        }
                    }
                case .traditional(let t):
                    track = t[currentPlaybackIndex]
                }
                guard track != nil && track!.url != nil else {
                    setSystemCurrentState(.error("File error")) // UI from secondary thread omg noooooooo
                    return
                }
                do {
                    try player = AVAudioPlayer(contentsOf: track!.url!)
                } catch {
                    setSystemCurrentState(.error("Player error"))
                    return
                }
                player.prepareToPlay()
                player.delegate = self
                player.numberOfLoops = 0
                player.isMeteringEnabled = true
                player.play()
                diskAnimationTargetState = .spinning
                currentTrack = track
                playbackIndexChanged = false
                controlCenterInfo.nowPlayingInfo = [
                    "albumTitle": track!.album ?? "Unknown",
                    "artist": track!.artist ?? "Unknown",
                    "title": track!.title ?? "Track \(currentPlaybackIndex + 1)",
                    "playbackDuration": TimeInterval(exactly: track!.length ?? 0.0) ?? "0.0",
                    "bookmarkTime": TimeInterval(exactly: 0.0)!,
                    MPNowPlayingInfoPropertyIsLiveStream: 0.0,
                ]
            }
        } else if (force != nil && !force!) || systemCurrentState == .playing {
            player.pause()
            setSystemCurrentState(.paused)
            diskAnimationTargetState = .stopped
        } else if systemCurrentState == .paused {
            if playbackIndexChanged {
                playPause(force: true)
                return
            }
            player.play()
            setSystemCurrentState(.playing)
            diskAnimationTargetState = .spinning
        } else if systemCurrentState == .standby {
            prepareDisk()
        }
    }
    
    func switchPlaybackMode(to: JunoAxioms.PlaybackMode? = nil) {
        guard systemCurrentState == .playing || systemCurrentState == .paused || systemCurrentState == .ready else { return }
        setupMenu.hide()
        let tos: JunoAxioms.PlaybackMode!
        if to != nil {
            tos = to
        } else {
            switch playbackMode {
            case .direct:
                tos = .repeatAll
            case .repeatAll:
                if case .progressive = mainDisk!.tracks {
                    tos = .repeatFolder
                } else {
                    tos = .repeatOne
                }
            case .repeatFolder:
                tos = .repeatOne
            case .repeatOne:
                if case .progressive = mainDisk!.tracks {
                    tos = .shuffleFolder
                } else {
                    tos = .shuffleAll
                }
            case .shuffleFolder:
                tos = .shuffleAll
            case .shuffleAll:
                tos = .direct
            }
        }
        playbackMode = tos
        switch tos {
        case .shuffleAll:
            if cachedTracks != nil {
                mainDisk!.tracks = cachedTracks!
            } else {
                cachedTracks = mainDisk!.tracks
            }
            mainDisk!.tracks.shuffle()
            cachedPlaybackIndex = currentPlaybackIndex
            currentPlaybackIndex = 0
            shuffleLightImageView.isHidden = false
            allLightImageView.isHidden = false
            folderLightImageView.isHidden = true
            oneLightImageView.isHidden = true
            repeatLightImageView.isHidden = true
        case .shuffleFolder:
            cachedTracks = mainDisk!.tracks
            mainDisk!.tracks.shuffle(folderIndex: currentFolderIndex)
            cachedPlaybackIndex = currentPlaybackIndex
            currentPlaybackIndex = 0
            shuffleLightImageView.isHidden = false
            allLightImageView.isHidden = true
            folderLightImageView.isHidden = false
            oneLightImageView.isHidden = true
            repeatLightImageView.isHidden = true
        case let k:
            if cachedTracks != nil {
                mainDisk!.tracks = cachedTracks!
                cachedTracks = nil
            }
            if cachedPlaybackIndex != nil {
                currentPlaybackIndex = cachedPlaybackIndex!
                cachedPlaybackIndex = nil
            }
            switch k {
            case .direct:
                shuffleLightImageView.isHidden = true
                allLightImageView.isHidden = true
                folderLightImageView.isHidden = true
                oneLightImageView.isHidden = true
                repeatLightImageView.isHidden = true
            case .repeatOne:
                shuffleLightImageView.isHidden = true
                allLightImageView.isHidden = true
                folderLightImageView.isHidden = true
                oneLightImageView.isHidden = false
                repeatLightImageView.isHidden = false
            case .repeatAll:
                shuffleLightImageView.isHidden = true
                allLightImageView.isHidden = false
                folderLightImageView.isHidden = true
                oneLightImageView.isHidden = true
                repeatLightImageView.isHidden = false
            case .repeatFolder:
                shuffleLightImageView.isHidden = true
                allLightImageView.isHidden = true
                folderLightImageView.isHidden = false
                oneLightImageView.isHidden = true
                repeatLightImageView.isHidden = false
            default: ()
            }
        }
    }
    
    func prepareDisk() {
        setSystemCurrentState(.busy)
        mainLabel.stringValue = "READING..."
        DispatchQueue.global(qos: .background).async {
            guard let disk = self.loadDisk() else {
                self.systemTargetState = .error("NO DISK")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.stopEject()
                }
                return
            }
            self.mainDisk = disk
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
            let fingerprint = self.getFingerprint(from: (diskParameters.0.count, diskParameters.1))
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
                } else if !(a.isHidden ?? true) && (knownBasicExtensions.contains(b.pathExtension) || knownHiResExtensions.contains(b.pathExtension)) {
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
            switchPlaybackMode(to: .direct)
            controlCenterInfo.playbackState = .stopped
            mainDisk = nil
        case .ready:
            diskLoadOneImageView.isHidden = false
            diskLoadTwoImageView.isHidden = false
            diskLoadThreeImageView.isHidden = false
            switchPlaybackMode(to: .direct)
            controlCenterInfo.playbackState = .stopped
            clearLabelIndicator()
        case let a:
            if a == .playing {
                levelIndicatorUpdateTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.updateLevelIndicator), userInfo: nil, repeats: true)
                controlCenterInfo.playbackState = .playing
            } else {
                if a != .paused {
                    switchPlaybackMode(to: .direct)
                    controlCenterInfo.playbackState = .stopped
                    controlCenterInfo.nowPlayingInfo = .none
                    if a == .standby {
                        mainDisk = nil
                    }
                } else {
                    controlCenterInfo.playbackState = .paused
                }
                clearLabelIndicator()
            }
        }
    }
    
    @objc
    func updateLevelIndicator() {
        player.updateMeters()
        levelIndicator.doubleValue = 50 - abs(Double(player.averagePower(forChannel: 0)))
    }
    
    func clearLabelIndicator() {
        guard levelIndicatorUpdateTimer != nil else { return }
        levelIndicatorUpdateTimer.invalidate()
        levelIndicator.doubleValue = 0.0
    }
    
    func lightsOut(withText: Bool = false) {
        trackIcoLightImageView.isHidden = true
        folderIcoLightImageView.isHidden = true
        knownLightImageView.isHidden = true
        mp3LightImageView.isHidden = true
        hiResLightImageView.isHidden = true
        repeatLightImageView.isHidden = true
        shuffleLightImageView.isHidden = true
        oneLightImageView.isHidden = true
        folderLightImageView.isHidden = true
        allLightImageView.isHidden = true
        diskLoadOneImageView.isHidden = true
        diskLoadTwoImageView.isHidden = true
        diskLoadThreeImageView.isHidden = true
        if withText {
            mainLabel.stringValue = ""
            additionalLabel.stringValue = ""
            numberLabel.stringValue = ""
        }
    }
    
    func displayToComply(with: JunoAxioms.Disk, includeDiskLoadLightReset: Bool = false) {
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
        if includeDiskLoadLightReset {
            diskLoadOneImageView.isHidden = false
            diskLoadTwoImageView.isHidden = false
            diskLoadThreeImageView.isHidden = false
        }
    }
    
    func displayToComply(with: JunoMenu) {
        mainLabel.stringValue = with.titleValue
        additionalLabel.stringValue = with.settingValue
        numberLabel.stringValue = String(with.index + 1)
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
                CATransaction.flush()
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
                self.rotateAnimation.fromValue = 0.0
                self.rotateAnimation.byValue = Double.pi * -2.0
                self.rotateAnimation.duration = 1
                self.rotateAnimation.timingFunction = .none
                self.rotateAnimation.repeatCount = .infinity
                self.rotateAnimation.isRemovedOnCompletion = true
                self.diskImageView.layer?.add(self.rotateAnimation, forKey: "rotation")
                complete()
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
    
    func shell(_ command: String) {
        DispatchQueue.main.async {
            let task = Process()
            task.launchPath = "/usr/bin/env"
            task.arguments = ["bash", "-c", command]
            task.launch()
            task.waitUntilExit()
        }
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
    
    func playSFX(_ named: String) {
        guard let url = Bundle.main.url(forResource: named, withExtension: "wav") else { print("E1"); return }
        try! SFXplayer = AVAudioPlayer(contentsOf: url)
        SFXplayer.volume = 0.3
        SFXplayer.play()
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
                if let f = ffdrew {
                    player.currentTime = f ? (player.currentTime + 4.0) : (player.currentTime - 4.0)
                }
                displayLabelType += 1
                guard currentTrack != nil else {
                    return
                }
                if currentTrack!.url!.pathExtension == "mp3" { // I don't really like this but who cares
                    mp3LightImageView.isHidden = false
                    hiResLightImageView.isHidden = true
                } else if knownHiResExtensions.contains(currentTrack!.url!.pathExtension) {
                    hiResLightImageView.isHidden = false
                    mp3LightImageView.isHidden = true
                } else {
                    hiResLightImageView.isHidden = true
                    mp3LightImageView.isHidden = true
                }
                switch displayLabelType {
                case 3: // Title
                    mainLabel.stringValue = currentTrack!.title ?? "Track \(currentPlaybackIndex + 1)"
                    if case .progressive = mainDisk!.tracks {
                        trackIcoLightImageView.isHidden = false
                        folderIcoLightImageView.isHidden = true
                        numberLabel.stringValue = String(currentPlaybackIndex + 1)
                    }
                case 6: // Artist
                    mainLabel.stringValue = "By \(currentTrack!.artist ?? "unknown")"
                case 9: // Album
                    mainLabel.stringValue = currentTrack!.album ?? "Album unknown"
                    if case .progressive = mainDisk!.tracks {
                        trackIcoLightImageView.isHidden = true
                        folderIcoLightImageView.isHidden = false
                        numberLabel.stringValue = String(currentFolderIndex + 1)
                    }
                    displayLabelType = 0
                default: ()
                }
                additionalLabel.stringValue = "-" + (timeString(from: player.currentTime.distance(to: currentTrack!.length!)) ?? "Playing")
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


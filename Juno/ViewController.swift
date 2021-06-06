//
//  ViewController.swift
//  Juno
//
//  Created by Lesterrry on 05.06.2021.
//

import Cocoa

class ViewController: NSViewController {
    
    //*********************************************************************
    //OUTLETS
    //*********************************************************************
    @IBOutlet weak var diskImageView: NSImageView!
    @IBOutlet weak var mainLabel: NSTextField!
    @IBOutlet weak var additionalLabel: NSTextField!
    
    //*********************************************************************
    //CONSTS
    //*********************************************************************
    let defaults = UserDefaults.standard
    
    //*********************************************************************
    //SYSTEM
    //*********************************************************************
    override func viewDidLoad() {
        super.viewDidLoad()
        //Setting the font programatically
        mainLabel.font = NSFont(name: "Opirus-OPIK", size: 27)
        additionalLabel.font = NSFont(name: "Opirus-OPIK", size: 27)
    }

    override var representedObject: Any? {
        didSet {

        }
    }
    
    override func viewDidAppear() {
        //Fetching data and performing all operations in async mode
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
        //Do what every player would do
        loadDisk()
    }

    //*********************************************************************
    //FUNCTIONS
    //*********************************************************************
    func loadDisk() {
        mainLabel.stringValue = "Reading..."
        if let vs = getVolumes() {
            mainLabel.stringValue = vs.lastPathComponent
        } else {
            mainLabel.stringValue = "No disc"
        }
    }
    
    func getVolumes() -> URL? {
        let filemanager = FileManager()
        let keys = [URLResourceKey.nameKey, URLResourceKey.volumeIsRemovableKey, URLResourceKey.nameKey, URLResourceKey.volumeAvailableCapacityKey] as Set<URLResourceKey>
        let paths = filemanager.mountedVolumeURLs(includingResourceValuesForKeys: .none, options: .skipHiddenVolumes)
        if paths == nil { return nil }
        for path in paths!{
            if try! path.resourceValues(forKeys: keys).volumeAvailableCapacity == 0 {
                print(path.absoluteURL)
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
            do {
                instance = try JSONDecoder().decode(JunoAxioms.InfoResponse.self, from: data! )
                semaphore.signal()
            } catch {}
        })
        task.resume()
        semaphore.wait()
        return instance
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


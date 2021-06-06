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
    @IBOutlet weak var dummyImageView: NSImageView!
    
    //*********************************************************************
    //CONSTS
    //*********************************************************************
    let defaults = UserDefaults.standard
    
    //*********************************************************************
    //SYSTEM
    //*********************************************************************
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
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
    }

    //*********************************************************************
    //FUNCTIONS
    //*********************************************************************
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
        dummyImageView.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        dummyImageView.layer?.position = CGPoint(x: dummyImageView.frame.origin.x + dummyImageView.frame.width / 2,
                                             y: dummyImageView.frame.origin.y + dummyImageView.frame.height / 2)
        dummyImageView.layer?.add(rotateAnimation, forKey: nil)
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


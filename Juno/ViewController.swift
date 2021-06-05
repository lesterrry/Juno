//
//  ViewController.swift
//  Juno
//
//  Created by Lesterrry on 05.06.2021.
//

import Cocoa

class ViewController: NSViewController {
    @IBOutlet weak var dummyImageView: NSImageView!
    
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
        getVolumes()
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
        dummyImageView.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        dummyImageView.layer?.position = CGPoint(x: dummyImageView.frame.origin.x + dummyImageView.frame.width / 2,
                                             y: dummyImageView.frame.origin.y + dummyImageView.frame.height / 2)
        dummyImageView.layer?.add(rotateAnimation, forKey: nil)
    }
    
    func fetchInfo() {
        let session = URLSession.shared
        let url = URL(string: JunoKeys.infoEndpoint + JunoKeys.infoKey)!
        let task = session.dataTask(with: url, completionHandler: { data, response, error in
            // Check the response
            if error != nil {
                return
            }
            do {
                let json = try JSONDecoder().decode(JunoAxioms.InfoResponse.self, from: data! )
                //try JSONSerialization.jsonObject(with: data!, options: [])
                print(json.version)
            } catch {}
        })
        task.resume()
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
}


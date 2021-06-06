//
//  AppDelegate.swift
//  Juno
//
//  Created by Lesterrry on 05.06.2021.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    
    @IBOutlet weak var shortMessageMenuItem: NSMenuItem!
    
    static var shortMessageLink = ""

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    @IBAction func githubMenuItemPressed(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://github.com/Lesterrry/Juno")!)
    }
    @IBAction func automneMenuItemPressed(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://github.com/Lesterrry/Radio-Automne")!)
    }
    @IBAction func contactMenuItemPressed(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://aydar.media")!)
    }
    @IBAction func shortMessageMenuItemPressed(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: AppDelegate.shortMessageLink)!)
    }
    
    public func initShortMessageMenuItem(title: String, link: String? = nil){
        shortMessageMenuItem.isHidden = false
        shortMessageMenuItem.title = title
        if link != nil {
            shortMessageMenuItem.isEnabled = true
            AppDelegate.shortMessageLink = link!
        }
    }

}


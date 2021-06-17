//
//  Menu.swift
//  Juno
//
//  Created by Lesterrry on 17.06.2021.
//

import Foundation

class JunoMenu {
    struct Setting { let title: String; let key: String; let values: [String]; var index: Int }
    
    enum MoveDirection { case up, down }
    
    public var index = 0
    public var invoked = false
    public var settings: [Setting]
    
    public var titleValue: String { return settings[index].title }
    public var settingValue: String { return settings[index].values[settings[index].index] }
    @discardableResult public func moveSetting(_ direction: MoveDirection) -> Self {
        if direction == .up {
            if index < settings.count - 1 {
                index += 1
            } else {
                index = 0
            }
        } else {
            if index > 0 {
                index -= 1
            } else {
                index = settings.count - 1
            }
        }; return self
    }
    @discardableResult public func moveValue(_ direction: MoveDirection) -> Self {
        if direction == .up {
            if settings[index].index < settings[index].values.count - 1 {
                settings[index].index += 1
            } else {
                settings[index].index = 0
            }
        } else {
            if settings[index].index > 0 {
                settings[index].index -= 1
            } else {
                settings[index].index = settings[index].values.count - 1
            }
        }
        return self
    }
    @discardableResult public func invoke() -> Self { invoked = true; return self }
    @discardableResult public func hide() -> Self { invoked = false; return self }
    
    init(_ settings: Setting...) {
        self.settings = settings
    }
}

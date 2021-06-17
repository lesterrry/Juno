//
//  Menu.swift
//  Juno
//
//  Created by Lesterrry on 17.06.2021.
//

import Foundation

class JunoMenu {
    struct Setting { let title: String; let values: [String]; var index: Int }
    
    enum MoveDirection { case up, down }
    
    private var index = 0
    private var invoked = false
    var settings: [Setting]
    
    var stringValue: String { return self.settings[index].title }
    @discardableResult func moveSetting(_ direction: MoveDirection) -> Self { if direction == .up { index += 1 } else { index -= 1 }; return self }
    @discardableResult func moveValue(_ direction: MoveDirection) -> Self { if direction == .up { settings[index].index += 1 } else { settings[index].index -= 1 }; return self }
    @discardableResult func invoke() -> Self { invoked = true; return self }
    @discardableResult func hide() -> Self { invoked = false; return self }
    
    init(_ settings: Setting...) {
        self.settings = settings
    }
}

//
//  Axioms.swift
//  Juno
//
//  Created by Lesterrry on 05.06.2021.
//
class JunoAxioms {
    class InfoResponse: Codable {
        let version: String
        let message: String?
        
        enum CodingKeys: String, CodingKey {
            case version, message
        }
        
        init(version: String, message: String){
            self.version = version
            self.message = message
        }
    }
}

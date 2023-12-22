//
//  ModalType.swift
//  7III Downwind
//
//  Created by Simon Lang on 22.12.23.
//

import Foundation

enum ModalType: Identifiable {
    var id: String {
        switch self {
        case .add:
            return "add"
        case .update:
            return "update"
        }
    }
    
    case add
    case update(Song)
}

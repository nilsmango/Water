//
//  CrewStatistic.swift
//  7III Downwind
//
//  Created by Simon Lang on 21.03.2024.
//

import Foundation

struct CrewStatistic: Codable {
    let memberID: UUID?
    let memberName: String
    var data: [StatisticData]
}

//
//  CountryPicker.swift
//  7III Downwind
//
//  Created by Simon Lang on 22.01.2026.
//

import SwiftUI

struct CountryPicker: View {
    @Binding var country: String
    @Binding var state: String?
    
    var body: some View {
        Section {
            Picker("Country", selection: $country) {
                Text("Select Country").tag("")
                Divider()
                ForEach(sortedCountries, id: \.code) { country in
                    Text(country.name).tag(country.code)
                }
            }
            
            if country == "US" {
                Picker("State", selection: $state) {
                    Text("Select State").tag(nil as String?)
                    Divider()
                    ForEach(usStates, id: \.code) { state in
                        Text(state.name).tag(state.code)
                    }
                }
            }
        }
    }
    
    private var sortedCountries: [Country] {
        countries.sorted { lhs, rhs in
            if lhs.code == "OTHER" { return true }
            if rhs.code == "OTHER" { return false }
            return lhs.name < rhs.name
        }
    }
}

struct Country {
    let code: String
    let name: String
}

let countries: [Country] = [
    Country(code: "OTHER", name: "Other (Not Listed)"),
    Country(code: "US", name: "United States"),
    Country(code: "CA", name: "Canada"),
    Country(code: "AU", name: "Australia"),
    Country(code: "GB", name: "United Kingdom"),
    Country(code: "DE", name: "Germany"),
    Country(code: "FR", name: "France"),
    Country(code: "ES", name: "Spain"),
    Country(code: "IT", name: "Italy"),
    Country(code: "CH", name: "Switzerland"),
    Country(code: "AT", name: "Austria"),
    Country(code: "PT", name: "Portugal"),
    Country(code: "NL", name: "Netherlands"),
    Country(code: "BE", name: "Belgium"),
    Country(code: "DK", name: "Denmark"),
    Country(code: "FI", name: "Finland"),
    Country(code: "NO", name: "Norway"),
    Country(code: "SE", name: "Sweden"),
    Country(code: "NZ", name: "New Zealand"),
    Country(code: "ZA", name: "South Africa"),
    Country(code: "BR", name: "Brazil"),
    Country(code: "MX", name: "Mexico"),
    Country(code: "AR", name: "Argentina"),
    Country(code: "CL", name: "Chile"),
    Country(code: "CO", name: "Colombia"),
    Country(code: "PE", name: "Peru")
]

let usStates: [UsState] = [
    UsState(code: "AL", name: "Alabama"),
    UsState(code: "AK", name: "Alaska"),
    UsState(code: "AZ", name: "Arizona"),
    UsState(code: "AR", name: "Arkansas"),
    UsState(code: "CA", name: "California"),
    UsState(code: "CO", name: "Colorado"),
    UsState(code: "CT", name: "Connecticut"),
    UsState(code: "DE", name: "Delaware"),
    UsState(code: "FL", name: "Florida"),
    UsState(code: "GA", name: "Georgia"),
    UsState(code: "HI", name: "Hawaii"),
    UsState(code: "ID", name: "Idaho"),
    UsState(code: "IL", name: "Illinois"),
    UsState(code: "IN", name: "Indiana"),
    UsState(code: "IA", name: "Iowa"),
    UsState(code: "KS", name: "Kansas"),
    UsState(code: "KY", name: "Kentucky"),
    UsState(code: "LA", name: "Louisiana"),
    UsState(code: "ME", name: "Maine"),
    UsState(code: "MD", name: "Maryland"),
    UsState(code: "MA", name: "Massachusetts"),
    UsState(code: "MI", name: "Michigan"),
    UsState(code: "MN", name: "Minnesota"),
    UsState(code: "MS", name: "Mississippi"),
    UsState(code: "MO", name: "Missouri"),
    UsState(code: "MT", name: "Montana"),
    UsState(code: "NE", name: "Nebraska"),
    UsState(code: "NV", name: "Nevada"),
    UsState(code: "NH", name: "New Hampshire"),
    UsState(code: "NJ", name: "New Jersey"),
    UsState(code: "NM", name: "New Mexico"),
    UsState(code: "NY", name: "New York"),
    UsState(code: "NC", name: "North Carolina"),
    UsState(code: "ND", name: "North Dakota"),
    UsState(code: "OH", name: "Ohio"),
    UsState(code: "OK", name: "Oklahoma"),
    UsState(code: "OR", name: "Oregon"),
    UsState(code: "PA", name: "Pennsylvania"),
    UsState(code: "RI", name: "Rhode Island"),
    UsState(code: "SC", name: "South Carolina"),
    UsState(code: "SD", name: "South Dakota"),
    UsState(code: "TN", name: "Tennessee"),
    UsState(code: "TX", name: "Texas"),
    UsState(code: "UT", name: "Utah"),
    UsState(code: "VT", name: "Vermont"),
    UsState(code: "VA", name: "Virginia"),
    UsState(code: "WA", name: "Washington"),
    UsState(code: "WV", name: "West Virginia"),
    UsState(code: "WI", name: "Wisconsin"),
    UsState(code: "WY", name: "Wyoming")
]

struct UsState {
    let code: String
    let name: String
}

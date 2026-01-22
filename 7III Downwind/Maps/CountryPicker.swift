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
    Country(code: "JP", name: "Japan"),
    Country(code: "BR", name: "Brazil"),
    Country(code: "NL", name: "Netherlands"),
    Country(code: "BE", name: "Belgium"),
    Country(code: "DK", name: "Denmark"),
    Country(code: "FI", name: "Finland"),
    Country(code: "NO", name: "Norway"),
    Country(code: "SE", name: "Sweden"),
    Country(code: "CH", name: "Switzerland"),
    Country(code: "AT", name: "Austria"),
    Country(code: "PT", name: "Portugal"),
    Country(code: "GR", name: "Greece"),
    Country(code: "IE", name: "Ireland"),
    Country(code: "NZ", name: "New Zealand"),
    Country(code: "ZA", name: "South Africa"),
    Country(code: "MX", name: "Mexico"),
    Country(code: "AR", name: "Argentina"),
    Country(code: "CL", name: "Chile"),
    Country(code: "CO", name: "Colombia"),
    Country(code: "PE", name: "Peru"),
    Country(code: "VE", name: "Venezuela"),
    Country(code: "RU", name: "Russia"),
    Country(code: "CN", name: "China"),
    Country(code: "IN", name: "India"),
    Country(code: "ID", name: "Indonesia"),
    Country(code: "MY", name: "Malaysia"),
    Country(code: "PH", name: "Philippines"),
    Country(code: "SG", name: "Singapore"),
    Country(code: "TH", name: "Thailand"),
    Country(code: "VN", name: "Vietnam"),
    Country(code: "AE", name: "United Arab Emirates"),
    Country(code: "SA", name: "Saudi Arabia"),
    Country(code: "EG", name: "Egypt"),
    Country(code: "MA", name: "Morocco"),
    Country(code: "TN", name: "Tunisia"),
    Country(code: "KE", name: "Kenya"),
    Country(code: "NG", name: "Nigeria"),
    Country(code: "GH", name: "Ghana"),
    Country(code: "AF", name: "Afghanistan"),
    Country(code: "AL", name: "Albania"),
    Country(code: "DZ", name: "Algeria"),
    Country(code: "AD", name: "Andorra"),
    Country(code: "AO", name: "Angola"),
    Country(code: "AG", name: "Antigua and Barbuda"),
    Country(code: "AM", name: "Armenia"),
    Country(code: "AZ", name: "Azerbaijan"),
    Country(code: "BS", name: "Bahamas"),
    Country(code: "BH", name: "Bahrain"),
    Country(code: "BD", name: "Bangladesh"),
    Country(code: "BB", name: "Barbados"),
    Country(code: "BY", name: "Belarus"),
    Country(code: "BZ", name: "Belize"),
    Country(code: "BJ", name: "Benin"),
    Country(code: "BT", name: "Bhutan"),
    Country(code: "BO", name: "Bolivia"),
    Country(code: "BA", name: "Bosnia and Herzegovina"),
    Country(code: "BW", name: "Botswana"),
    Country(code: "BN", name: "Brunei"),
    Country(code: "BG", name: "Bulgaria"),
    Country(code: "BF", name: "Burkina Faso"),
    Country(code: "BI", name: "Burundi"),
    Country(code: "KH", name: "Cambodia"),
    Country(code: "CM", name: "Cameroon"),
    Country(code: "CV", name: "Cape Verde"),
    Country(code: "CF", name: "Central African Republic"),
    Country(code: "TD", name: "Chad"),
    Country(code: "HR", name: "Croatia"),
    Country(code: "CU", name: "Cuba"),
    Country(code: "CY", name: "Cyprus"),
    Country(code: "CZ", name: "Czech Republic"),
    Country(code: "CD", name: "Democratic Republic of the Congo"),
    Country(code: "DO", name: "Dominican Republic"),
    Country(code: "EC", name: "Ecuador"),
    Country(code: "SV", name: "El Salvador"),
    Country(code: "GQ", name: "Equatorial Guinea"),
    Country(code: "ER", name: "Eritrea"),
    Country(code: "EE", name: "Estonia"),
    Country(code: "ET", name: "Ethiopia"),
    Country(code: "FJ", name: "Fiji"),
    Country(code: "GA", name: "Gabon"),
    Country(code: "GM", name: "Gambia"),
    Country(code: "GE", name: "Georgia"),
    Country(code: "GT", name: "Guatemala"),
    Country(code: "GN", name: "Guinea"),
    Country(code: "GW", name: "Guinea-Bissau"),
    Country(code: "GY", name: "Guyana"),
    Country(code: "HT", name: "Haiti"),
    Country(code: "HN", name: "Honduras"),
    Country(code: "HU", name: "Hungary"),
    Country(code: "IS", name: "Iceland"),
    Country(code: "IR", name: "Iran"),
    Country(code: "IQ", name: "Iraq"),
    Country(code: "IL", name: "Israel"),
    Country(code: "JM", name: "Jamaica"),
    Country(code: "JO", name: "Jordan"),
    Country(code: "KZ", name: "Kazakhstan"),
    Country(code: "KW", name: "Kuwait"),
    Country(code: "KG", name: "Kyrgyzstan"),
    Country(code: "LA", name: "Laos"),
    Country(code: "LV", name: "Latvia"),
    Country(code: "LB", name: "Lebanon"),
    Country(code: "LS", name: "Lesotho"),
    Country(code: "LR", name: "Liberia"),
    Country(code: "LY", name: "Libya"),
    Country(code: "LI", name: "Liechtenstein"),
    Country(code: "LT", name: "Lithuania"),
    Country(code: "LU", name: "Luxembourg"),
    Country(code: "MG", name: "Madagascar"),
    Country(code: "MW", name: "Malawi"),
    Country(code: "MV", name: "Maldives"),
    Country(code: "ML", name: "Mali"),
    Country(code: "MT", name: "Malta"),
    Country(code: "MR", name: "Mauritania"),
    Country(code: "MU", name: "Mauritius"),
    Country(code: "MD", name: "Moldova"),
    Country(code: "MC", name: "Monaco"),
    Country(code: "MN", name: "Mongolia"),
    Country(code: "ME", name: "Montenegro"),
    Country(code: "MZ", name: "Mozambique"),
    Country(code: "MM", name: "Myanmar"),
    Country(code: "NA", name: "Namibia"),
    Country(code: "NP", name: "Nepal"),
    Country(code: "NI", name: "Nicaragua"),
    Country(code: "NE", name: "Niger"),
    Country(code: "KP", name: "North Korea"),
    Country(code: "MK", name: "North Macedonia"),
    Country(code: "OM", name: "Oman"),
    Country(code: "PK", name: "Pakistan"),
    Country(code: "PS", name: "Palestine"),
    Country(code: "PA", name: "Panama"),
    Country(code: "PG", name: "Papua New Guinea"),
    Country(code: "PY", name: "Paraguay"),
    Country(code: "PL", name: "Poland"),
    Country(code: "QA", name: "Qatar"),
    Country(code: "RO", name: "Romania"),
    Country(code: "RW", name: "Rwanda"),
    Country(code: "KN", name: "Saint Kitts and Nevis"),
    Country(code: "LC", name: "Saint Lucia"),
    Country(code: "VC", name: "Saint Vincent and the Grenadines"),
    Country(code: "WS", name: "Samoa"),
    Country(code: "SM", name: "San Marino"),
    Country(code: "ST", name: "Sao Tome and Principe"),
    Country(code: "SN", name: "Senegal"),
    Country(code: "RS", name: "Serbia"),
    Country(code: "SC", name: "Seychelles"),
    Country(code: "SL", name: "Sierra Leone"),
    Country(code: "SK", name: "Slovakia"),
    Country(code: "SI", name: "Slovenia"),
    Country(code: "SB", name: "Solomon Islands"),
    Country(code: "SO", name: "Somalia"),
    Country(code: "KR", name: "South Korea"),
    Country(code: "SS", name: "South Sudan"),
    Country(code: "LK", name: "Sri Lanka"),
    Country(code: "SD", name: "Sudan"),
    Country(code: "SR", name: "Suriname"),
    Country(code: "SZ", name: "Eswatini"),
    Country(code: "SY", name: "Syria"),
    Country(code: "TJ", name: "Tajikistan"),
    Country(code: "TZ", name: "Tanzania"),
    Country(code: "TL", name: "Timor-Leste"),
    Country(code: "TG", name: "Togo"),
    Country(code: "TO", name: "Tonga"),
    Country(code: "TT", name: "Trinidad and Tobago"),
    Country(code: "TR", name: "Turkey"),
    Country(code: "TM", name: "Turkmenistan"),
    Country(code: "TV", name: "Tuvalu"),
    Country(code: "UG", name: "Uganda"),
    Country(code: "UA", name: "Ukraine"),
    Country(code: "UY", name: "Uruguay"),
    Country(code: "UZ", name: "Uzbekistan"),
    Country(code: "VU", name: "Vanuatu"),
    Country(code: "VA", name: "Vatican City"),
    Country(code: "YE", name: "Yemen"),
    Country(code: "ZM", name: "Zambia"),
    Country(code: "ZW", name: "Zimbabwe")
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

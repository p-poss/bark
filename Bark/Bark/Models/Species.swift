import Foundation

enum Species: String, CaseIterable, Codable, Identifiable {
    // Broadleaf
    case oak = "English Oak"
    case beech = "European Beech"
    case ash = "Common Ash"
    case sycamore = "Sycamore"
    case hornbeam = "Hornbeam"
    case sweetChestnut = "Sweet Chestnut"
    case horseChestnut = "Horse Chestnut"
    case silverBirch = "Silver Birch"
    case alder = "Common Alder"
    case willow = "Weeping Willow"
    case poplar = "Black Poplar"
    case lime = "Common Lime"
    case fieldMaple = "Field Maple"
    case wildCherry = "Wild Cherry"
    case rowan = "Rowan"

    // Conifer
    case scotsPine = "Scots Pine"
    case yew = "English Yew"
    case larch = "European Larch"
    case douglasFir = "Douglas Fir"
    case norwaySpruce = "Norway Spruce"

    // Fallback
    case unknownBroadleaf = "Unknown Broadleaf"
    case unknownConifer = "Unknown Conifer"

    var id: String { rawValue }

    var scientificName: String {
        switch self {
        case .oak: return "Quercus robur"
        case .beech: return "Fagus sylvatica"
        case .ash: return "Fraxinus excelsior"
        case .sycamore: return "Acer pseudoplatanus"
        case .hornbeam: return "Carpinus betulus"
        case .sweetChestnut: return "Castanea sativa"
        case .horseChestnut: return "Aesculus hippocastanum"
        case .silverBirch: return "Betula pendula"
        case .alder: return "Alnus glutinosa"
        case .willow: return "Salix babylonica"
        case .poplar: return "Populus nigra"
        case .lime: return "Tilia x europaea"
        case .fieldMaple: return "Acer campestre"
        case .wildCherry: return "Prunus avium"
        case .rowan: return "Sorbus aucuparia"
        case .scotsPine: return "Pinus sylvestris"
        case .yew: return "Taxus baccata"
        case .larch: return "Larix decidua"
        case .douglasFir: return "Pseudotsuga menziesii"
        case .norwaySpruce: return "Picea abies"
        case .unknownBroadleaf: return "Unknown"
        case .unknownConifer: return "Unknown"
        }
    }

    var family: String {
        switch self {
        case .oak: return "Fagaceae"
        case .beech: return "Fagaceae"
        case .sweetChestnut: return "Fagaceae"
        case .ash: return "Oleaceae"
        case .sycamore, .fieldMaple: return "Sapindaceae"
        case .hornbeam: return "Betulaceae"
        case .horseChestnut: return "Sapindaceae"
        case .silverBirch, .alder: return "Betulaceae"
        case .willow, .poplar: return "Salicaceae"
        case .lime: return "Malvaceae"
        case .wildCherry: return "Rosaceae"
        case .rowan: return "Rosaceae"
        case .scotsPine, .douglasFir, .norwaySpruce, .larch: return "Pinaceae"
        case .yew: return "Taxaceae"
        case .unknownBroadleaf, .unknownConifer: return "Unknown"
        }
    }

    /// Average growth factor in cm DBH per year
    var averageGrowthFactor: Double {
        switch self {
        case .oak: return 1.8
        case .beech: return 2.0
        case .ash: return 2.5
        case .sycamore: return 2.2
        case .hornbeam: return 1.5
        case .sweetChestnut: return 2.0
        case .horseChestnut: return 2.3
        case .silverBirch: return 2.5
        case .alder: return 2.2
        case .willow: return 3.5  // Fast growing
        case .poplar: return 3.0
        case .lime: return 1.8
        case .fieldMaple: return 1.5
        case .wildCherry: return 2.5
        case .rowan: return 2.0
        case .scotsPine: return 2.0
        case .yew: return 0.8  // Very slow growing
        case .larch: return 2.5
        case .douglasFir: return 2.8
        case .norwaySpruce: return 2.3
        case .unknownBroadleaf: return 2.0
        case .unknownConifer: return 2.0
        }
    }

    /// Maximum known age in years
    var maxAge: Int {
        switch self {
        case .oak: return 1000
        case .beech: return 400
        case .ash: return 400
        case .sycamore: return 400
        case .hornbeam: return 300
        case .sweetChestnut: return 700
        case .horseChestnut: return 300
        case .silverBirch: return 100
        case .alder: return 150
        case .willow: return 80
        case .poplar: return 200
        case .lime: return 500
        case .fieldMaple: return 350
        case .wildCherry: return 100
        case .rowan: return 200
        case .scotsPine: return 500
        case .yew: return 2000  // Ancient
        case .larch: return 250
        case .douglasFir: return 500
        case .norwaySpruce: return 500
        case .unknownBroadleaf: return 300
        case .unknownConifer: return 300
        }
    }

    var barkDescription: String {
        switch self {
        case .oak: return "Deep vertical fissures, grey-brown, very rough"
        case .beech: return "Smooth, grey, thin bark often with horizontal markings"
        case .ash: return "Pale grey with regular diamond-shaped fissures"
        case .sycamore: return "Smooth when young, becoming scaly and flaking with age"
        case .hornbeam: return "Smooth, grey with vertical ridges"
        case .sweetChestnut: return "Develops deep spiral fissures with age"
        case .horseChestnut: return "Grey-brown, scaly, peeling in older trees"
        case .silverBirch: return "Distinctive white, papery bark with black diamonds"
        case .alder: return "Dark grey-brown with shallow fissures"
        case .willow: return "Grey-brown, deeply fissured with intersecting ridges"
        case .poplar: return "Pale grey, smooth when young, deeply fissured when old"
        case .lime: return "Grey-brown, smooth becoming ridged with age"
        case .fieldMaple: return "Grey-brown, corky, developing fissures"
        case .wildCherry: return "Shiny, red-brown with horizontal bands"
        case .rowan: return "Smooth, shiny, grey-brown"
        case .scotsPine: return "Orange-red upper trunk, grey-brown plates below"
        case .yew: return "Red-brown, thin, flaking in strips"
        case .larch: return "Grey-brown, scaly, becoming deeply fissured"
        case .douglasFir: return "Thick, corky, deeply furrowed with dark brown ridges"
        case .norwaySpruce: return "Grey-brown, thin, scaly"
        case .unknownBroadleaf: return "Variable bark texture"
        case .unknownConifer: return "Variable bark texture"
        }
    }

    var isConifer: Bool {
        switch self {
        case .scotsPine, .yew, .larch, .douglasFir, .norwaySpruce, .unknownConifer:
            return true
        default:
            return false
        }
    }

    var funFacts: [String] {
        switch self {
        case .oak:
            return [
                "Can live over 1000 years",
                "Supports over 2000 species of wildlife",
                "Was sacred to Druids"
            ]
        case .yew:
            return [
                "Can live over 2000 years",
                "Associated with churchyards since pre-Christian times",
                "All parts are highly toxic except the flesh of berries"
            ]
        case .silverBirch:
            return [
                "Pioneer species that colonizes open ground",
                "Bark was traditionally used to make canoes",
                "Symbol of renewal and purification"
            ]
        default:
            return []
        }
    }
}

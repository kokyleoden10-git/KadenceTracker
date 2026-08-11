import Foundation

/// The chart as a value type — twelve signs plus everything derived from
/// them. Extracted so the resonance engine doesn't care whether the chart
/// came from SwiftData (during migration) or Supabase (everywhere else),
/// and so this logic exists once rather than on each storage model.
struct ChartPlacements: Hashable {
    var sun: ZodiacSign
    var moon: ZodiacSign
    var mercury: ZodiacSign
    var venus: ZodiacSign
    var mars: ZodiacSign
    var jupiter: ZodiacSign
    var saturn: ZodiacSign
    var uranus: ZodiacSign
    var neptune: ZodiacSign
    var pluto: ZodiacSign
    var ascendant: ZodiacSign
    var midheaven: ZodiacSign

    var planets: [Planet: ZodiacSign] {
        [.sun: sun, .moon: moon, .mercury: mercury, .venus: venus, .mars: mars,
         .jupiter: jupiter, .saturn: saturn, .uranus: uranus, .neptune: neptune, .pluto: pluto]
    }

    /// Every point that gets a name in the UI, in a stable display order.
    var named: [(String, ZodiacSign)] {
        [("Sun", sun), ("Moon", moon), ("Mercury", mercury), ("Venus", venus),
         ("Mars", mars), ("Jupiter", jupiter), ("Saturn", saturn), ("Uranus", uranus),
         ("Neptune", neptune), ("Pluto", pluto), ("Ascendant", ascendant), ("Midheaven", midheaven)]
    }

    /// Which natal points sit in each sign.
    var occupants: [ZodiacSign: [String]] {
        var map: [ZodiacSign: [String]] = [:]
        for (name, sign) in named {
            map[sign, default: []].append(name)
        }
        return map
    }

    /// Whole-sign houses: the Ascendant's sign is the 1st, the rest follow
    /// in zodiac order. `houses[0]` is the 1st house.
    var houses: [ZodiacSign] {
        let signs = ZodiacSign.allCases
        guard let startIndex = signs.firstIndex(of: ascendant) else { return signs }
        return (0..<12).map { signs[(startIndex + $0) % 12] }
    }

    func house(of sign: ZodiacSign) -> Int? {
        houses.firstIndex(of: sign).map { $0 + 1 }
    }

    /// Tallies count the ten planets plus both angles — 12 points. The
    /// angles are structural enough to belong in a "what is this chart made
    /// of" summary, which is what these are for.
    static let talliedPointCount = 12

    private var talliedSigns: [ZodiacSign] {
        Array(planets.values) + [ascendant, midheaven]
    }

    var elementTally: [Element: Int] {
        var tally: [Element: Int] = [.fire: 0, .water: 0, .air: 0, .earth: 0]
        for sign in talliedSigns {
            tally[element(of: sign), default: 0] += 1
        }
        return tally
    }

    var modalityTally: [Modality: Int] {
        var tally: [Modality: Int] = [.cardinal: 0, .fixed: 0, .mutable: 0]
        for sign in talliedSigns {
            tally[modality(of: sign), default: 0] += 1
        }
        return tally
    }
}

extension RemoteNatalChart {
    var placements: ChartPlacements {
        ChartPlacements(
            sun: sun, moon: moon, mercury: mercury, venus: venus, mars: mars,
            jupiter: jupiter, saturn: saturn, uranus: uranus, neptune: neptune,
            pluto: pluto, ascendant: ascendant, midheaven: midheaven
        )
    }
}

extension NatalChart {
    var placementsValue: ChartPlacements {
        ChartPlacements(
            sun: sun, moon: moon, mercury: mercury, venus: venus, mars: mars,
            jupiter: jupiter, saturn: saturn, uranus: uranus, neptune: neptune,
            pluto: pluto, ascendant: ascendant, midheaven: midheaven
        )
    }
}

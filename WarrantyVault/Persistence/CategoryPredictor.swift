import Foundation
import NaturalLanguage


final class CategoryPredictor {

    static let shared = CategoryPredictor()

    private let embedding: NLEmbedding?


    private let brandMap: [(token: String, category: WarrantyCategory)] = [

        ("apple", .electronics), ("iphone", .electronics), ("ipad", .electronics),
        ("macbook", .electronics), ("airpods", .electronics), ("apple watch", .electronics),
        ("samsung galaxy", .electronics), ("samsung qled", .electronics), ("samsung neo qled", .electronics),
        ("sony", .electronics), ("playstation", .electronics), ("ps5", .electronics),
        ("xbox", .electronics), ("nintendo", .electronics), ("steam deck", .electronics),
        ("dell", .electronics), ("hp laserjet", .electronics), ("lenovo", .electronics),
        ("asus", .electronics), ("acer", .electronics), ("microsoft surface", .electronics),
        ("bose", .electronics), ("beats", .electronics), ("jbl", .electronics),
        ("sonos", .electronics), ("anker", .electronics), ("logitech", .electronics),
        ("razer", .electronics), ("garmin", .electronics), ("fitbit", .electronics),
        ("oura", .electronics), ("kindle", .electronics), ("roku", .electronics),
        ("dji", .electronics), ("gopro", .electronics), ("canon", .electronics),
        ("nikon", .electronics), ("pixel", .electronics), ("synology", .electronics),
        ("eero", .electronics), ("meta quest", .electronics), ("insta360", .electronics),
        ("lg oled", .electronics), ("lg tv", .electronics),


        ("lg washtower", .appliance), ("lg washer", .appliance), ("lg french door", .appliance),
        ("samsung bespoke", .appliance), ("samsung family hub", .appliance),
        ("whirlpool", .appliance), ("maytag", .appliance), ("kitchenaid", .appliance),
        ("ge profile", .appliance), ("ge cafe", .appliance), ("ge appliances", .appliance),
        ("frigidaire", .appliance), ("kenmore", .appliance),
        ("bosch dishwasher", .appliance), ("bosch washer", .appliance), ("bosch range", .appliance),
        ("dyson v15", .appliance), ("dyson airwrap", .appliance), ("dyson pure cool", .appliance),
        ("shark", .appliance), ("bissell", .appliance), ("hoover", .appliance),
        ("roomba", .appliance), ("irobot", .appliance),
        ("instant pot", .appliance), ("vitamix", .appliance), ("ninja foodi", .appliance),
        ("breville", .appliance), ("keurig", .appliance), ("cuisinart", .appliance),
        ("levoit", .appliance), ("honeywell hepa", .appliance),


        ("tesla", .vehicle), ("toyota", .vehicle), ("ford", .vehicle), ("honda", .vehicle),
        ("nissan", .vehicle), ("hyundai", .vehicle), ("kia", .vehicle), ("mazda", .vehicle),
        ("subaru", .vehicle), ("jeep", .vehicle), ("ram 1500", .vehicle), ("chevrolet", .vehicle),
        ("gmc", .vehicle), ("bmw", .vehicle), ("mercedes-benz", .vehicle), ("mercedes benz", .vehicle),
        ("audi", .vehicle), ("lexus", .vehicle), ("polestar", .vehicle), ("rivian", .vehicle),
        ("volkswagen", .vehicle),
        ("michelin", .vehicle), ("bridgestone", .vehicle), ("goodyear", .vehicle),
        ("continental tire", .vehicle), ("napa", .vehicle), ("acdelco", .vehicle),
        ("mobil 1", .vehicle), ("optima yellowtop", .vehicle), ("diehard", .vehicle),
        ("weathertech", .vehicle), ("thule", .vehicle), ("yakima", .vehicle),


        ("herman miller", .furniture), ("steelcase", .furniture), ("knoll", .furniture),
        ("ikea", .furniture), ("west elm", .furniture), ("pottery barn", .furniture),
        ("crate and barrel", .furniture), ("crate & barrel", .furniture),
        ("article", .furniture), ("floyd", .furniture), ("burrow", .furniture),
        ("joybird", .furniture), ("restoration hardware", .furniture),
        ("la-z-boy", .furniture), ("la z boy", .furniture),
        ("casper", .furniture), ("purple mattress", .furniture), ("saatva", .furniture),
        ("tempur-pedic", .furniture), ("tempur pedic", .furniture),
        ("eames", .furniture), ("aeron", .furniture),
        ("rove concepts", .furniture), ("inside weather", .furniture),
        ("lovesac", .furniture),


        ("tiffany", .jewelry), ("cartier", .jewelry), ("bvlgari", .jewelry),
        ("van cleef", .jewelry), ("hermes clic", .jewelry), ("mikimoto", .jewelry),
        ("pandora", .jewelry), ("kay jewelers", .jewelry), ("zales", .jewelry),
        ("blue nile", .jewelry), ("james allen", .jewelry), ("brilliant earth", .jewelry),
        ("david yurman", .jewelry), ("kendra scott", .jewelry), ("alex and ani", .jewelry),
        ("mejuri", .jewelry), ("aurate", .jewelry), ("catbird", .jewelry),
        ("ana luisa", .jewelry), ("forevermark", .jewelry), ("helzberg", .jewelry),
        ("jared", .jewelry), ("ben bridge", .jewelry),
        ("rolex", .jewelry), ("omega watch", .jewelry), ("tag heuer", .jewelry),
        ("seiko", .jewelry), ("citizen eco-drive", .jewelry), ("movado", .jewelry),
        ("daniel wellington", .jewelry),


        ("dewalt", .tools), ("milwaukee", .tools), ("makita", .tools),
        ("ryobi", .tools), ("ridgid", .tools), ("hilti", .tools),
        ("klein tools", .tools), ("knipex", .tools), ("wera", .tools),
        ("snap-on", .tools), ("snap on", .tools), ("channellock", .tools),
        ("craftsman", .tools), ("husky tool", .tools), ("stanley fatmax", .tools),
        ("estwing", .tools), ("fluke", .tools), ("festool", .tools),
        ("bosch drill", .tools), ("bosch saw", .tools), ("bosch hammer", .tools),
        ("bosch jigsaw", .tools), ("bosch rotary hammer", .tools),
        ("hitachi nail", .tools), ("hitachi roofing", .tools),
        ("sawstop", .tools),
    ]


    private let categoryAnchors: [WarrantyCategory: [String]] = [
        .electronics: ["phone", "laptop", "television", "headphones", "camera",
                       "tablet", "monitor", "speaker", "console", "smartwatch"],
        .appliance:   ["refrigerator", "washer", "dryer", "vacuum", "oven",
                       "microwave", "dishwasher", "blender", "toaster"],
        .vehicle:     ["car", "truck", "vehicle", "automobile", "tire",
                       "sedan", "motorcycle"],
        .furniture:   ["chair", "sofa", "couch", "table", "bed",
                       "desk", "dresser", "mattress", "bookshelf"],
        .jewelry:     ["ring", "necklace", "watch", "earrings", "bracelet",
                       "diamond", "pearl"],
        .tools:       ["drill", "saw", "hammer", "wrench", "screwdriver",
                       "sander", "toolkit"],
    ]


    private let embeddingDistanceThreshold: Double = 1.0

    init() {
        self.embedding = NLEmbedding.wordEmbedding(for: .english)
    }


    func predict(from text: String) -> WarrantyCategory? {
        let lower = text.lowercased()


        var best: (token: String, category: WarrantyCategory)?
        for (token, category) in brandMap where lower.contains(token) {
            if let current = best, current.token.count >= token.count { continue }
            best = (token, category)
        }
        if let best { return best.category }


        return predictByEmbedding(in: lower)
    }


    var isAvailable: Bool { true }


    private func predictByEmbedding(in lowercaseText: String) -> WarrantyCategory? {
        guard let embedding else { return nil }

        let words = lowercaseText
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }
        let uniqueWords = Array(Set(words))
        guard !uniqueWords.isEmpty else { return nil }

        var bestCategory: WarrantyCategory?
        var bestDistance = Double.infinity

        for (category, anchors) in categoryAnchors {
            var minDistance = Double.infinity
            for anchor in anchors {
                for word in uniqueWords {
                    let d = embedding.distance(between: word, and: anchor)
                    if d < minDistance { minDistance = d }
                }
            }
            if minDistance < bestDistance {
                bestDistance = minDistance
                bestCategory = category
            }
        }

        return bestDistance < embeddingDistanceThreshold ? bestCategory : nil
    }
}

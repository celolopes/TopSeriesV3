import Foundation

struct WatchProvider: Codable, Identifiable {
    let logoPath: String?
    let providerName: String?
    
    var id: String { providerName ?? UUID().uuidString }
    
    var logoURL: URL? {
        guard let path = logoPath, !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/original\(path)")
    }
    
    enum CodingKeys: String, CodingKey {
        case logoPath = "logo_path"
        case providerName = "provider_name"
    }
}

struct WatchProviderResponse: Codable {
    let results: WatchProviderResults
}

struct WatchProviderResults: Codable {
    let br: WatchProviderDetails?
    
    enum CodingKeys: String, CodingKey {
        case br = "BR"
    }
}

struct WatchProviderDetails: Codable {
    let flatrate: [WatchProvider]?
}

struct TVShow: Identifiable, Codable {
    let id: Int
    var name: String
    var originalName: String?
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let firstAirDate: String?
    let voteAverage: Double?
    var trailerKey: String?
    var watchProviders: [WatchProvider]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case originalName = "original_name"
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case trailerKey
        case watchProviders
    }
    
    var posterURL: URL? {
        guard let path = posterPath, !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }
    
    var backdropURL: URL? {
        guard let path = backdropPath, !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/original\(path)")
    }
    
    var formattedRating: String {
        if let rating = voteAverage {
            return String(format: "%.1f", rating)
        }
        return "N/A"
    }
    
    var formattedFirstAirDate: String {
        guard let date = firstAirDate, !date.isEmpty else { return "Data não disponível" }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "pt_BR")
        
        if let parsedDate = dateFormatter.date(from: date) {
            dateFormatter.dateFormat = "dd/MM/yyyy"
            return dateFormatter.string(from: parsedDate)
        }
        
        return "Data não disponível"
    }
} 
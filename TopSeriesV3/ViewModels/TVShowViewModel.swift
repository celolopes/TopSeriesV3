import Foundation
import SwiftUI

enum TimeWindow: String, CaseIterable, Identifiable {
    case day = "day"
    case week = "week"
    case month = "month"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .day: return "Hoje"
        case .week: return "Esta Semana"
        case .month: return "Este Mês"
        }
    }
}

enum APIError: LocalizedError {
    case invalidResponse(message: String)
    case decodingError(message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse(let message):
            return "Erro na resposta da API: \(message)"
        case .decodingError(let message):
            return "Erro ao decodificar dados: \(message)"
        }
    }
}

struct APIErrorResponse: Codable {
    let statusMessage: String
    
    enum CodingKeys: String, CodingKey {
        case statusMessage = "status_message"
    }
}

@MainActor
class TVShowViewModel: ObservableObject {
    @Published var shows: [TVShow] = []
    @Published var selectedShow: TVShow?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var selectedTimeWindow: TimeWindow = .week
    
    private let bearerToken = "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJlYWYyMmFhNzFjMzZkZGM0Y2QzMzBhYjI4ZGViNWU5MiIsIm5iZiI6MTczNzQ5MzgwNC4xODQsInN1YiI6IjY3OTAwZDJjZTFhZjIwNTkwZmFhYzlmMCIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.b4d-z37DnAEgr8qqRSm3fRTAyoUd_Hqg-YQSs04afhU"
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }
    
    func fetchTopShows() async {
        isLoading = true
        shows = []
        selectedShow = nil
        
        do {
            var url: URL
            var components: URLComponents
            
            if selectedTimeWindow == .month {
                // Para o modo mensal, usar discover/tv
                url = URL(string: "https://api.themoviedb.org/3/discover/tv")!
                components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                
                let today = Date()
                let sixtyDaysAgo = Calendar.current.date(byAdding: .day, value: -60, to: today)!
                
                components.queryItems = [
                    URLQueryItem(name: "language", value: "pt-BR"),
                    URLQueryItem(name: "sort_by", value: "popularity.desc"),
                    URLQueryItem(name: "with_original_language", value: "en"),
                    URLQueryItem(name: "vote_count.gte", value: "20"),
                    URLQueryItem(name: "watch_region", value: "BR"),
                    URLQueryItem(name: "with_type", value: "2|4"), // Séries de TV e Minisséries
                    URLQueryItem(name: "first_air_date.gte", value: dateFormatter.string(from: sixtyDaysAgo)),
                    URLQueryItem(name: "first_air_date.lte", value: dateFormatter.string(from: today)),
                    URLQueryItem(name: "with_status", value: "0|3"), // Em produção ou em andamento
                    URLQueryItem(name: "with_release_type", value: "2|4|6") // Séries de TV, Minisséries e Streaming
                ]
            } else {
                // Para dia e semana, usar trending
                url = URL(string: "https://api.themoviedb.org/3/trending/tv/\(selectedTimeWindow.rawValue)")!
                components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
                components.queryItems = [
                    URLQueryItem(name: "language", value: "pt-BR"),
                    URLQueryItem(name: "region", value: "BR")
                ]
            }
            
            guard let finalURL = components.url else {
                throw URLError(.badURL)
            }
            
            var request = URLRequest(url: finalURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    let errorMessage = try? JSONDecoder().decode(APIErrorResponse.self, from: data).statusMessage
                    throw APIError.invalidResponse(message: errorMessage ?? "Status code: \(httpResponse.statusCode)")
                }
            }
            
            let showsResponse = try JSONDecoder().decode(TVShowResponse.self, from: data)
            var newShows = Array(showsResponse.results.prefix(5))
            
            for i in 0..<newShows.count {
                if let trailerKey = await fetchTrailer(for: newShows[i].id) {
                    newShows[i].trailerKey = trailerKey
                }
                
                if let providers = await fetchWatchProviders(for: newShows[i].id) {
                    newShows[i].watchProviders = providers
                }
            }
            
            await MainActor.run {
                self.shows = newShows
                self.selectedShow = newShows.first
                self.error = nil
            }
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    private func fetchTrailer(for showId: Int) async -> String? {
        // 1. Primeiro tenta buscar vídeos em Português
        if let trailers = await fetchTrailersForLanguage(showId: showId, language: "pt-BR") {
            let allVideos = trailers.filter { $0.site == "YouTube" }
            
            // Primeiro tenta encontrar trailers legendados
            if let legendadoVideo = allVideos.first(where: { 
                ($0.type == "Trailer" || $0.type == "Teaser") && 
                ($0.name.lowercased().contains("legendado") || 
                 $0.name.lowercased().contains("leg"))
            }) {
                return legendadoVideo.key
            }
            
            // Depois tenta encontrar trailers dublados
            if let dubladoVideo = allVideos.first(where: { 
                ($0.type == "Trailer" || $0.type == "Teaser") && 
                ($0.name.lowercased().contains("dublado") || 
                 $0.name.lowercased().contains("dub"))
            }) {
                return dubladoVideo.key
            }
            
            // Por último, tenta qualquer vídeo em português
            let videoTypes = ["Trailer", "Teaser", "Clip", "Featurette", "Behind the Scenes"]
            for videoType in videoTypes {
                if let video = allVideos.first(where: { $0.type == videoType }) {
                    return video.key
                }
            }
        }

        // 2. Se não encontrar em português, tenta em inglês
        if let trailers = await fetchTrailersForLanguage(showId: showId, language: "en-US") {
            let allVideos = trailers.filter { $0.site == "YouTube" }
            let videoTypes = ["Trailer", "Teaser", "Clip", "Featurette", "Behind the Scenes"]
            
            for videoType in videoTypes {
                if let video = allVideos.first(where: { $0.type == videoType }) {
                    return video.key
                }
            }
        }
        
        return nil
    }
    
    private func fetchTrailersForLanguage(showId: Int, language: String) async -> [Video]? {
        do {
            let urlComponents = URLComponents(string: "https://api.themoviedb.org/3/tv/\(showId)/videos")!
            
            var components = urlComponents
            components.queryItems = [
                URLQueryItem(name: "language", value: language)
            ]
            
            guard let url = components.url else { return nil }
            
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                throw APIError.invalidResponse(message: "Status code: \(httpResponse.statusCode)")
            }
            
            let videosResponse = try JSONDecoder().decode(VideoResponse.self, from: data)
            return videosResponse.results
        } catch {
            return nil
        }
    }
    
    private func fetchWatchProviders(for showId: Int) async -> [WatchProvider]? {
        // 1. Primeiro tenta buscar provedores da API oficial
        if let providers = await fetchProvidersFromAPI(for: showId) {
            return providers
        }
        
        // 2. Se não encontrar, tenta buscar na descrição da série
        if let providers = await extractProvidersFromShowDetails(showId: showId) {
            return providers
        }
        
        // 3. Se ainda não encontrar, tenta buscar nos vídeos
        if let trailerKey = await fetchTrailer(for: showId) {
            if let providers = await extractProvidersFromVideo(videoId: trailerKey) {
                return providers
            }
        }
        
        return nil
    }
    
    private func fetchProvidersFromAPI(for showId: Int) async -> [WatchProvider]? {
        do {
            let urlComponents = URLComponents(string: "https://api.themoviedb.org/3/tv/\(showId)/watch/providers")!
            
            guard let url = urlComponents.url else { return nil }
            
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                throw APIError.invalidResponse(message: "Status code: \(httpResponse.statusCode)")
            }
            
            let providersResponse = try JSONDecoder().decode(WatchProviderResponse.self, from: data)
            return providersResponse.results.br?.flatrate
        } catch {
            return nil
        }
    }
    
    private func extractProvidersFromShowDetails(showId: Int) async -> [WatchProvider]? {
        do {
            let urlComponents = URLComponents(string: "https://api.themoviedb.org/3/tv/\(showId)")!
            
            var components = urlComponents
            components.queryItems = [
                URLQueryItem(name: "language", value: "pt-BR"),
                URLQueryItem(name: "append_to_response", value: "keywords,external_ids")
            ]
            
            guard let url = components.url else { return nil }
            
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            
            struct ShowDetails: Codable {
                let overview: String
                let networks: [Network]
                
                struct Network: Codable {
                    let name: String
                }
            }
            
            let showDetails = try JSONDecoder().decode(ShowDetails.self, from: data)
            var providers: [WatchProvider] = []
            
            let providerKeywords = [
                "Netflix": (["netflix", "série original netflix", "netflix original"], "/t2yyOv40HZeVlLjYsCsPHnWLk4W.jpg"),
                "Prime Video": (["prime video", "amazon prime", "amazon original"], "/emthp39XA2YScoYL1p0sdbAH2WA.jpg"),
                "Disney+": (["disney+", "disney plus", "série original disney"], "/7rwgEs15tFwyR9NPQ5vpzxTj19Q.jpg"),
                "Star+": (["star+", "star plus"], "/zqPiJW4AeFS4OQkJvNnxgJ0eFaV.jpg"),
                "HBO Max": (["hbo max", "hbo", "max original"], "/aS2zvJWn9mwiCOeaaCkIh4wleZS.jpg"),
                "Apple TV+": (["apple tv+", "apple tv plus", "apple original"], "/6uhKBfmtzFqOcLousHwZuzcrScK.jpg"),
                "Paramount+": (["paramount+", "paramount plus"], "/xbhHHa1YgtpwhC8lb1NQ3ACVcLd.jpg"),
                "Globoplay": (["globoplay"], "/jPXksH9rTFDgiU4ZBQkgPWUuKpi.jpg"),
                "Discovery+": (["discovery+", "discovery plus"], "/1D1bS3Dyw4ScYnFWTlBOvJXC3nb.jpg"),
                "Universal+": (["universal+", "universal plus"], "/oWPBXgmRxF6VUH1gsoI6bfKF4d.jpg")
            ]
            
            let textToSearch = showDetails.overview.lowercased() + " " + 
                              showDetails.networks.map { $0.name.lowercased() }.joined(separator: " ")
            
            for (providerName, (keywords, logo)) in providerKeywords {
                for keyword in keywords {
                    if textToSearch.contains(keyword) {
                        providers.append(WatchProvider(logoPath: logo, providerName: providerName))
                        break
                    }
                }
            }
            
            if !providers.isEmpty {
                return providers
            }
            
            for network in showDetails.networks {
                if let provider = mapNetworkToProvider(network.name) {
                    providers.append(provider)
                }
            }
            
            return providers.isEmpty ? nil : providers
        } catch {
            return nil
        }
    }
    
    private func mapNetworkToProvider(_ networkName: String) -> WatchProvider? {
        let networkMappings = [
            "Netflix": ("Netflix", "/t2yyOv40HZeVlLjYsCsPHnWLk4W.jpg"),
            "Amazon": ("Prime Video", "/emthp39XA2YScoYL1p0sdbAH2WA.jpg"),
            "Disney+": ("Disney Plus", "/7rwgEs15tFwyR9NPQ5vpzxTj19Q.jpg"),
            "Star+": ("Star Plus", "/zqPiJW4AeFS4OQkJvNnxgJ0eFaV.jpg"),
            "HBO": ("HBO Max", "/aS2zvJWn9mwiCOeaaCkIh4wleZS.jpg"),
            "Apple TV+": ("Apple TV Plus", "/6uhKBfmtzFqOcLousHwZuzcrScK.jpg"),
            "Paramount": ("Paramount Plus", "/xbhHHa1YgtpwhC8lb1NQ3ACVcLd.jpg"),
            "Globoplay": ("Globoplay", "/jPXksH9rTFDgiU4ZBQkgPWUuKpi.jpg"),
            "Discovery": ("Discovery+", "/1D1bS3Dyw4ScYnFWTlBOvJXC3nb.jpg"),
            "Universal": ("Universal+", "/oWPBXgmRxF6VUH1gsoI6bfKF4d.jpg")
        ]
        
        for (network, (provider, logo)) in networkMappings {
            if networkName.lowercased().contains(network.lowercased()) {
                return WatchProvider(logoPath: logo, providerName: provider)
            }
        }
        
        return nil
    }
    
    private func extractProvidersFromVideo(videoId: String) async -> [WatchProvider]? {
        do {
            let url = URL(string: "https://www.googleapis.com/youtube/v3/videos?id=\(videoId)&part=snippet&key=AIzaSyBVQcd6kYhCQDOFQz6kSO_Fy6Ry5kSvXKw")!
            
            let (data, response) = try await session.data(for: URLRequest(url: url))
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            
            struct YouTubeResponse: Codable {
                let items: [YouTubeItem]
            }
            
            struct YouTubeItem: Codable {
                let snippet: Snippet
            }
            
            struct Snippet: Codable {
                let description: String
                let title: String
                let channelTitle: String
            }
            
            let youtubeResponse = try JSONDecoder().decode(YouTubeResponse.self, from: data)
            
            if let item = youtubeResponse.items.first {
                var providers: [WatchProvider] = []
                
                let textToSearch = [
                    item.snippet.title,
                    item.snippet.description,
                    item.snippet.channelTitle
                ].joined(separator: " ").lowercased()
                
                let providerKeywords = [
                    "Netflix": (["netflix", "série original netflix", "netflix original", "só na netflix", "exclusivo netflix"], "/t2yyOv40HZeVlLjYsCsPHnWLk4W.jpg"),
                    "Prime Video": (["prime video", "amazon prime", "amazon original", "prime original"], "/emthp39XA2YScoYL1p0sdbAH2WA.jpg"),
                    "Disney+": (["disney+", "disney plus", "série original disney", "disney original"], "/7rwgEs15tFwyR9NPQ5vpzxTj19Q.jpg"),
                    "Star+": (["star+", "star plus", "série star original"], "/zqPiJW4AeFS4OQkJvNnxgJ0eFaV.jpg"),
                    "HBO Max": (["hbo max", "hbo", "max original", "série hbo"], "/aS2zvJWn9mwiCOeaaCkIh4wleZS.jpg"),
                    "Apple TV+": (["apple tv+", "apple tv plus", "apple original", "apple tv"], "/6uhKBfmtzFqOcLousHwZuzcrScK.jpg"),
                    "Paramount+": (["paramount+", "paramount plus", "série paramount"], "/xbhHHa1YgtpwhC8lb1NQ3ACVcLd.jpg"),
                    "Globoplay": (["globoplay", "original globoplay"], "/jPXksH9rTFDgiU4ZBQkgPWUuKpi.jpg"),
                    "Discovery+": (["discovery+", "discovery plus"], "/1D1bS3Dyw4ScYnFWTlBOvJXC3nb.jpg"),
                    "Universal+": (["universal+", "universal plus"], "/oWPBXgmRxF6VUH1gsoI6bfKF4d.jpg")
                ]
                
                for (providerName, (keywords, logo)) in providerKeywords {
                    for keyword in keywords {
                        if textToSearch.contains(keyword) {
                            providers.append(WatchProvider(logoPath: logo, providerName: providerName))
                            break
                        }
                    }
                }
                
                return providers.isEmpty ? nil : providers
            }
            
            return nil
        } catch {
            return nil
        }
    }
    
    private func fetchTranslatedTitle(for showId: Int) async -> String? {
        do {
            let urlComponents = URLComponents(string: "https://api.themoviedb.org/3/tv/\(showId)")!
            
            var components = urlComponents
            components.queryItems = [
                URLQueryItem(name: "language", value: "pt-BR")
            ]
            
            guard let url = components.url else { return nil }
            
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                return nil
            }
            
            struct ShowDetails: Codable {
                let name: String
                
                enum CodingKeys: String, CodingKey {
                    case name
                }
            }
            
            let showDetails = try JSONDecoder().decode(ShowDetails.self, from: data)
            return showDetails.name
        } catch {
            return nil
        }
    }
}

struct TVShowResponse: Codable {
    let results: [TVShow]
}

struct VideoResponse: Codable {
    let results: [Video]
}

struct Video: Codable {
    let key: String
    let site: String
    let type: String
    let name: String
} 
import SwiftUI

struct ShowDetailsView: View {
    let show: TVShow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Banner
            if let backdropURL = show.backdropURL {
                AsyncImage(url: backdropURL) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color(white: 0.2))
                            .frame(height: 200)
                            .overlay(
                                ProgressView()
                                    .controlSize(.regular)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(Color(white: 0.2))
                            .frame(height: 200)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                // Título e informações básicas
                Text(show.name)
                    .font(.title)
                    .fontWeight(.bold)
                
                if let originalName = show.originalName, originalName != show.name {
                    Text("Título Original: \(originalName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text("Data de Estreia: \(show.formattedFirstAirDate)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Avaliação: \(show.formattedRating)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !show.overview.isEmpty {
                    // Sinopse
                    Text("Sinopse:")
                        .font(.headline)
                        .padding(.top, 5)
                    
                    Text(show.overview)
                        .font(.body)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
        }
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }
}

struct StreamingProvidersView: View {
    let providers: [WatchProvider]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Disponível em:")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 5)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(providers) { provider in
                        ProviderItemView(provider: provider)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 100)
        }
        .padding(.vertical, 5)
    }
}

struct ProviderItemView: View {
    let provider: WatchProvider
    
    var body: some View {
        VStack {
            if let logoURL = provider.logoURL {
                AsyncImage(url: logoURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 50, height: 50)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                    case .failure:
                        Image(systemName: "play.tv")
                            .font(.system(size: 30))
                            .frame(width: 50, height: 50)
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            
            Text(provider.providerName ?? "Não disponível")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 80)
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = TVShowViewModel()
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Cabeçalho
                HStack {
                    Text("Top Séries")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Picker("Período", selection: $viewModel.selectedTimeWindow) {
                        ForEach(TimeWindow.allCases) { timeWindow in
                            Text(timeWindow.displayName)
                                .tag(timeWindow)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 300)
                }
                .padding()
                .background(Color(white: 0.1))
                
                // Conteúdo principal
                HStack(spacing: 0) {
                    // Lista de séries
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.shows) { show in
                                TVShowPosterView(show: show, isSelected: show.id == viewModel.selectedShow?.id)
                                    .onTapGesture {
                                        withAnimation {
                                            viewModel.selectedShow = show
                                        }
                                    }
                            }
                        }
                        .padding(.vertical)
                    }
                    .frame(width: 200)
                    .background(Color(white: 0.05))
                    
                    // Detalhes da série selecionada
                    ScrollView(.vertical, showsIndicators: false) {
                        if let error = viewModel.error {
                            VStack(spacing: 20) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 50))
                                    .foregroundColor(.red)
                                
                                Text("Erro ao carregar dados")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text(error.localizedDescription)
                                    .font(.body)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
                                Button(action: {
                                    Task {
                                        await viewModel.fetchTopShows()
                                    }
                                }) {
                                    Text("Tentar Novamente")
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if let selectedShow = viewModel.selectedShow {
                            VStack(spacing: 20) {
                                ShowDetailsView(show: selectedShow)
                                
                                if let providers = selectedShow.watchProviders, !providers.isEmpty {
                                    StreamingProvidersView(providers: providers)
                                        .padding(.horizontal)
                                }
                                
                                if let trailerKey = selectedShow.trailerKey {
                                    VStack(alignment: .leading) {
                                        Text("Trailer")
                                            .font(.headline)
                                            .padding(.leading)
                                        
                                        YouTubePlayerView(videoId: trailerKey)
                                            .frame(height: 300)
                                            .cornerRadius(12)
                                            .padding(.horizontal)
                                    }
                                }
                            }
                            .padding(.vertical)
                        } else {
                            Text("")
                                .font(.title2)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .background(Color(white: 0.05))
                }
            }
            .opacity(viewModel.isLoading ? 0.3 : 1.0)
            
            if viewModel.isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .controlSize(.large)
                    
                    Text("Buscando as melhores séries...")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                .padding(40)
                .background(Color(white: 0.1))
                .cornerRadius(15)
                .shadow(radius: 10)
            }
        }
        .task {
            if viewModel.shows.isEmpty {
                await viewModel.fetchTopShows()
            }
        }
        .onChange(of: viewModel.selectedTimeWindow) { oldValue, newValue in
            Task {
                await viewModel.fetchTopShows()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 

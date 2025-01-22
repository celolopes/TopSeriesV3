import SwiftUI

struct TVShowPosterView: View {
    let show: TVShow
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Group {
                if let url = show.posterURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color(white: 0.2))
                                .frame(width: 140, height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                                .overlay(
                                    ProgressView()
                                        .controlSize(.regular)
                                )
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 140, height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                        case .failure:
                            Rectangle()
                                .fill(Color(white: 0.2))
                                .frame(width: 140, height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundColor(Color.white.opacity(0.5))
                                )
                        @unknown default:
                            Rectangle()
                                .fill(Color(white: 0.2))
                                .frame(width: 140, height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                    }
                } else {
                    Rectangle()
                        .fill(Color(white: 0.2))
                        .frame(width: 140, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(Color.white.opacity(0.5))
                        )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                    .shadow(color: isSelected ? Color.blue.opacity(0.5) : Color.clear, radius: 8)
            )
            
            Text(show.name)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(Color.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 140)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .opacity(isSelected ? 1 : 0.8)
        .scaleEffect(isSelected ? 1.05 : 1)
        .animation(.spring(response: 0.3), value: isSelected)
    }
} 
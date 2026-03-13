import SwiftUI

// MARK: - Avatar View
struct AvatarView: View {
    let name: String
    let size: CGFloat
    var avatarUrl: String? = nil

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var color: Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .teal, .indigo, .mint]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }

    var body: some View {
        if let urlString = avatarUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                case .failure:
                    fallbackAvatar
                default:
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.2))
                        ProgressView()
                            .scaleEffect(size > 40 ? 0.6 : 0.4)
                    }
                    .frame(width: size, height: size)
                }
            }
        } else {
            fallbackAvatar
        }
    }

    private var fallbackAvatar: some View {
        ZStack {
            Circle()
                .fill(color.gradient)
            Text(initials)
                .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let status: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(status)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Grade Badge
struct GradeBadge: View {
    let grade: Grade

    var body: some View {
        Text(grade.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(gradeColor.opacity(0.1))
            .foregroundStyle(gradeColor)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    var gradeColor: Color {
        switch grade {
        case .ic: return .gray
        case .lead: return .blue
        case .associatePrincipal: return .purple
        case .principal: return .orange
        case .executivePrincipal: return .red
        case .executiveOfficer: return .red
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Proficiency Dots
struct ProficiencyDots: View {
    let level: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= level ? Color.blue : Color.blue.opacity(0.15))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

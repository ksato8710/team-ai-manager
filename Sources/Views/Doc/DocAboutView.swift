import SwiftUI

struct DocAboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Hero
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.3.sequence.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.blue.gradient)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Team AI Manager")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Text("AI-Driven Team Management for Design & Development Organizations")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                // What is this tool?
                DocSection(title: "このツールについて", icon: "info.circle.fill", color: .blue) {
                    Text("""
                    Team AI Manager は、デザイン・開発組織のチームマネジメントを AI で加速するための Mac ネイティブアプリケーションです。

                    約40名規模のチームが、10社程度のクライアントと常時15ほどのプロジェクトを推進する環境で、メンバー・プロジェクト・クライアントを一元管理し、AI ドリブンで改善サイクルを回し続けることを目的としています。
                    """)
                    .font(.body)
                    .lineSpacing(6)
                }

                // Target Organization
                DocSection(title: "想定する組織", icon: "building.2.fill", color: .purple) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("デザイン・開発の専門チームを想定しています。具体的には Simplex Group のデザイン組織 Alceo のような体制です。")
                            .font(.body)
                            .lineSpacing(4)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            OrgMetricCard(value: "~40", label: "メンバー", icon: "person.3")
                            OrgMetricCard(value: "~10", label: "クライアント", icon: "building.2")
                            OrgMetricCard(value: "~15", label: "同時進行プロジェクト", icon: "folder")
                        }

                        Text("ロール構成")
                            .font(.headline)
                            .padding(.top, 8)

                        let roles = [
                            ("UX Designer", "ユーザー体験設計、インタラクションデザイン"),
                            ("UI Designer", "ビジュアルデザイン、デザインシステム"),
                            ("UX Researcher", "ユーザーリサーチ、ユーザビリティテスト"),
                            ("Frontend Engineer", "Web/モバイルフロントエンド開発"),
                            ("Service Designer", "サービスブループリント、ビジネスデザイン"),
                            ("Brand Designer", "ブランドアイデンティティ、VI設計"),
                        ]
                        ForEach(roles, id: \.0) { role, desc in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(role).fontWeight(.medium)
                                    Text(desc).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }

                        Text("グレード体系")
                            .font(.headline)
                            .padding(.top, 8)

                        let grades = [
                            ("Executive Officer", "組織統括"),
                            ("Executive Principal", "技術/デザイン領域統括"),
                            ("Principal", "大規模プロジェクトリード"),
                            ("Associate Principal", "プロジェクトリード/専門家"),
                            ("Lead", "チームリード/実行者"),
                            ("Staff (IC)", "個人貢献者"),
                        ]
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(Array(grades.enumerated()), id: \.0) { idx, grade in
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle()
                                            .fill(gradeColor(idx).gradient)
                                            .frame(width: 36, height: 36)
                                        Text("\(grades.count - idx)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.white)
                                    }
                                    Text(grade.0)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .multilineTextAlignment(.center)
                                    Text(grade.1)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                if idx < grades.count - 1 {
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .padding(.top, 10)
                                }
                            }
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                // Core Capabilities
                DocSection(title: "コア機能", icon: "cpu.fill", color: .green) {
                    let capabilities: [(String, String, String, Color)] = [
                        ("person.3", "メンバー管理", "ロール、グレード、スキル、稼働状況の一元管理。プロジェクトへのアサインと稼働率の可視化。", .blue),
                        ("folder.fill", "プロジェクト管理", "ステータス、フェーズ、クライアント紐づけ、チーム構成の管理。サービスタイプ別の分類。", .green),
                        ("building.2.fill", "クライアント管理", "業界、ドメイン、関係ステータスの管理。プロジェクト履歴の追跡。", .purple),
                        ("star.fill", "スキルマトリクス", "チーム全体のスキル分布をヒートマップで可視化。スキルギャップの特定。", .orange),
                        ("book.fill", "ナレッジベース", "ケーススタディ、プロセス、ガイドライン、チーム原則の共有と蓄積。", .pink),
                        ("brain", "AI インサイト", "ワークロード分析、スキルギャップ検出、スタッフィングレコメンデーション。", .indigo),
                        ("antenna.radiowaves.left.and.right", "スキャナー", "Slack、GitHub、Figma 等の外部ソースから活動ログを自動取り込み。", .teal),
                    ]

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(capabilities, id: \.1) { icon, title, desc, color in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .foregroundStyle(color)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineSpacing(2)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                // AI Vision
                DocSection(title: "AI 活用のビジョン", icon: "sparkles", color: .indigo) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("\"team ai manager\" の名前に AI を入れているのは、AI を使ってすべてのことを加速させたいからです。")
                            .font(.body)
                            .italic()
                            .foregroundStyle(.secondary)

                        let phases: [(String, String, String)] = [
                            ("Phase 1: スキャン & 変換",
                             "日々の活動ログ（Slack、GitHub、Figma等）を AI でスキャンし、定義したデータモデルに変換。組織に自然になじむ形でデータを蓄積。",
                             "antenna.radiowaves.left.and.right"),
                            ("Phase 2: 分析 & 予測",
                             "メンバーやプロジェクトの稼働状況・進捗を分析し、先々の見通しを立てる。リスクの早期検知。",
                             "chart.line.uptrend.xyaxis"),
                            ("Phase 3: レコメンデーション",
                             "スキルやロールに基づいたアサイン最適化。プロジェクトに最適なメンバーの提案。",
                             "person.badge.plus"),
                            ("Phase 4: オンボーディング",
                             "新メンバーの効率的なオンボーディング支援。スキルマップに基づく成長プランの自動生成。",
                             "arrow.up.right.circle"),
                        ]

                        ForEach(Array(phases.enumerated()), id: \.0) { idx, phase in
                            HStack(alignment: .top, spacing: 16) {
                                VStack(spacing: 0) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.indigo.gradient)
                                            .frame(width: 32, height: 32)
                                        Text("\(idx + 1)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.white)
                                    }
                                    if idx < phases.count - 1 {
                                        Rectangle()
                                            .fill(Color.indigo.opacity(0.3))
                                            .frame(width: 2, height: 40)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Image(systemName: phase.2)
                                            .foregroundStyle(.indigo)
                                        Text(phase.0)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                    Text(phase.1)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineSpacing(3)
                                }
                            }
                        }
                    }
                }

                // Scanner Architecture
                DocSection(title: "スキャナーアーキテクチャ", icon: "puzzlepiece.extension.fill", color: .teal) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("外部ソースからのデータ取り込みは、プラグインベースの拡張可能な仕組みとして設計しています。新しいソースの追加は ScannerProtocol を実装するだけで可能です。")
                            .font(.body)
                            .lineSpacing(4)

                        let sources: [(String, String, String)] = [
                            ("message.fill", "Slack", "コミュニケーションパターン、ナレッジ共有の検出"),
                            ("chevron.left.forwardslash.chevron.right", "GitHub", "コード貢献、レビュー活動、スキルシグナル"),
                            ("paintbrush.fill", "Figma", "デザイン活動、コンポーネント利用状況"),
                            ("checklist", "Jira", "タスク完了、プロジェクト進捗"),
                            ("doc.text.fill", "Notion", "ドキュメント作成、ナレッジ蓄積"),
                            ("calendar", "Calendar", "ミーティング、ワークショップ活動"),
                        ]

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(sources, id: \.1) { icon, name, desc in
                                VStack(spacing: 6) {
                                    Image(systemName: icon)
                                        .font(.title3)
                                        .foregroundStyle(.teal)
                                    Text(name)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text(desc)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }

                        // Flow diagram
                        HStack(spacing: 0) {
                            flowStep("外部ソース", "Slack/GitHub/Figma...", .teal)
                            flowArrow()
                            flowStep("Scanner", "ScannerProtocol", .blue)
                            flowArrow()
                            flowStep("AI 変換", "構造化データへ", .indigo)
                            flowArrow()
                            flowStep("SQLite", "データモデルに格納", .green)
                        }
                        .padding(.top, 8)
                    }
                }

                // Tech Stack
                DocSection(title: "技術スタック", icon: "hammer.fill", color: .gray) {
                    let stack: [(String, String)] = [
                        ("UI フレームワーク", "SwiftUI (macOS 14+)"),
                        ("言語", "Swift 5.9+"),
                        ("データベース", "SQLite (GRDB.swift)"),
                        ("AI 統合", "Claude API (Anthropic)"),
                        ("パッケージ管理", "Swift Package Manager"),
                        ("アーキテクチャ", "MVVM + NavigationSplitView"),
                    ]

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(stack, id: \.0) { label, value in
                            HStack {
                                Text(label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(value)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(10)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(32)
            .frame(maxWidth: 900)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func gradeColor(_ index: Int) -> Color {
        let colors: [Color] = [.red, .orange, .purple, .blue, .cyan, .gray]
        return colors[index % colors.count]
    }

    private func flowStep(_ title: String, _ subtitle: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func flowArrow() -> some View {
        Image(systemName: "arrow.right")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 4)
    }
}

// MARK: - Reusable Doc Components

struct DocSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title3)
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
            }
            content
        }
    }
}

struct OrgMetricCard: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

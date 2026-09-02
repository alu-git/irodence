import SwiftUI

struct CommentsSheet: View {
    let targetID: UUID
    let title: String
    let viewerID: UUID
    let viewerName: String

    @StateObject private var service = CommentService()
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    init(targetID: UUID, title: String? = nil, viewerID: UUID, viewerName: String = "我") {
        self.targetID = targetID
        self.title = title ?? L10n.t("评论", "Comments")
        self.viewerID = viewerID
        self.viewerName = viewerName
    }

    init(item: FeedItem, viewerID: UUID, viewerName: String) {
        self.targetID = item.id
        self.title = item.name
        self.viewerID = viewerID
        self.viewerName = viewerName
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Comments list
                if service.isLoading && service.comments.isEmpty {
                    Spacer()
                    GymLoadingView(L10n.t("加载评论中…", "Loading comments…"))
                    Spacer()
                } else if service.comments.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 36))
                            .foregroundStyle(Theme.Colors.textMuted)
                        Text(L10n.t("暂无评论，来抢沙发吧！", "No comments yet. Be the first!"))
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 18) {
                                ForEach(service.comments) { comment in
                                    CommentRow(comment: comment)
                                        .id(comment.id)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                        }
                        .onChange(of: service.comments.count) { _ in
                            if let last = service.comments.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                    }
                }

                Divider()
                    .background(Theme.Colors.borderHairline)

                // Input bar
                HStack(spacing: 12) {
                    AvatarView(name: viewerName, size: 36)

                    TextField(L10n.t("写评论…", "Write a comment…"), text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($inputFocused)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Theme.Colors.surfaceSunken)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                        )

                    Button {
                        Task {
                            let text = draft
                            draft = ""
                            await service.post(
                                workoutID: targetID,
                                body: text,
                                userID: viewerID,
                                displayName: viewerName
                            )
                        }
                    } label: {
                        if service.isSending {
                            ProgressView()
                                .tint(Theme.Colors.ember)
                                .frame(width: 32, height: 32)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Theme.Colors.textMuted
                                    : Theme.Colors.ember)
                        }
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || service.isSending)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Theme.Colors.surfaceRaised)
            }
            .background(Theme.Colors.surfaceBase.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("关闭", "Close")) { dismiss() }
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
            }
            .task { await service.load(workoutID: targetID) }
            .alert(L10n.t("出错了", "Error"), isPresented: Binding(
                get: { service.errorMessage != nil },
                set: { if !$0 { service.errorMessage = nil } }
            )) {
                Button("OK") { service.errorMessage = nil }
            } message: {
                Text(service.errorMessage ?? "")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - One comment row

private struct CommentRow: View {
    let comment: WorkoutComment
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(name: comment.displayName, size: 40)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(comment.displayName)
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(comment.relativeTimeText)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                Text(comment.body)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}

#if DEBUG
import SwiftUI

/// DEBUG-only 「开发者预览」 section shown at the bottom of ProfileView.
/// One-tap ways to see populated UI states without real training data.
struct DebugPreviewSection: View {
    let userID: UUID

    @EnvironmentObject private var library: ExerciseService
    @StateObject private var mock = DebugMockService()
    @StateObject private var photos = ProgressPhotoService()
    @State private var showSummaryPreview = false

    var body: some View {
        Section {
            Button { showSummaryPreview = true } label: {
                Label("预览训练完成页 + 动画", systemImage: "trophy.fill")
            }

            Button {
                Task { await mock.followMockUsers(userID: userID) }
            } label: {
                Label("关注模拟用户（填充动态）", systemImage: "person.2.fill")
            }

            Button {
                Task { await mock.seedMyActivity(userID: userID, library: library) }
            } label: {
                Label("生成我的历史训练 + PR", systemImage: "clock.arrow.circlepath")
            }

            Button {
                Task { await mock.seedMyPhotos(using: photos) }
            } label: {
                Label("上传模拟照片", systemImage: "photo.stack")
            }

            if mock.isBusy {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(mock.status ?? "…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let status = mock.status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("开发者预览")
        } footer: {
            Text("模拟用户由 supabase/seed.sql 创建（在 Supabase SQL 编辑器里运行一次）")
        }
        .disabled(mock.isBusy)
        .sheet(isPresented: $showSummaryPreview) {
            WorkoutSummaryView(summary: DebugMockService.mockSummary(library: library))
        }
    }
}
#endif

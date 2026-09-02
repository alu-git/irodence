import SwiftUI
import PhotosUI

/// Modal sheet for editing user profile information: Avatar, Display Name,
/// Bio, Sex, Bodyweight, Height, and Age.
struct EditProfileSheet: View {
    let profile: Profile
    @ObservedObject var service: ProfileService

    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String
    @State private var sex: Sex?
    @State private var bodyweightInput: String
    @State private var bio: String
    @State private var heightInput: String
    @State private var ageInput: String
    @State private var avatarURL: String

    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(profile: Profile, service: ProfileService) {
        self.profile = profile
        self.service = service
        _displayName = State(initialValue: profile.displayName)
        _sex = State(initialValue: profile.sex)
        _bodyweightInput = State(initialValue: profile.bodyweightKg.map { String(format: "%.1f", $0) } ?? "")
        _bio = State(initialValue: profile.bio ?? "")
        _heightInput = State(initialValue: profile.heightCm.map { String(format: "%.0f", $0) } ?? "")
        _ageInput = State(initialValue: profile.ageYears.map { String($0) } ?? "")
        _avatarURL = State(initialValue: profile.avatarURL ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Avatar Section
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            ZStack {
                                if let selectedImageData, let uiImage = UIImage(data: selectedImageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 84, height: 84)
                                        .clipShape(Circle())
                                } else if let url = URL(string: avatarURL), !avatarURL.isEmpty {
                                    AsyncImage(url: url) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        Circle().fill(Color.accentColor.opacity(0.15))
                                    }
                                    .frame(width: 84, height: 84)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(LinearGradient(
                                            colors: [.accentColor.opacity(0.8), .accentColor],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .frame(width: 84, height: 84)
                                        .overlay {
                                            Text(String(displayName.prefix(1)).uppercased())
                                                .font(.largeTitle.bold())
                                                .foregroundStyle(.white)
                                        }
                                }

                                Circle()
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 2)
                                    .frame(width: 84, height: 84)
                            }

                            PhotosPicker(selection: $pickerItem, matching: .images) {
                                Label(L10n.t("更换头像", "Change Photo"), systemImage: "photo.badge.plus")
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                // MARK: - Basic Info Section
                Section(header: Text(L10n.t("基本资料", "Basic Info"))) {
                    HStack {
                        Text(L10n.t("昵称", "Name"))
                        Spacer()
                        TextField(L10n.t("请输入昵称", "Enter name"), text: $displayName)
                            .multilineTextAlignment(.trailing)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.t("个人简介", "Bio"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField(L10n.t("分享你的健身目标或座右铭…", "Share your fitness goals or quote…"), text: $bio, axis: .vertical)
                            .lineLimit(2...4)
                    }
                    .padding(.vertical, 2)
                }

                // MARK: - Physical Attributes
                Section(header: Text(L10n.t("身体数据", "Body Metrics"))) {
                    Picker(L10n.t("性别", "Sex"), selection: $sex) {
                        Text(L10n.t("未设置", "Not Set")).tag(Sex?.none)
                        ForEach(Sex.allCases, id: \.self) { sexOption in
                            Text(sexOption.displayName).tag(Sex?.some(sexOption))
                        }
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Text(L10n.t("年龄", "Age"))
                        Spacer()
                        TextField("25", text: $ageInput)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                        Text(L10n.t("岁", "yrs")).foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(L10n.t("体重", "Bodyweight"))
                        Spacer()
                        TextField("70.0", text: $bodyweightInput)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                        Text("kg").foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(L10n.t("身高", "Height"))
                        Spacer()
                        TextField("175", text: $heightInput)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                        Text("cm").foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(L10n.t("编辑个人资料", "Edit Profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("取消", "Cancel")) {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveProfile()
                    } label: {
                        if isSaving {
                            GymLoadingView()
                        } else {
                            Text(L10n.t("保存", "Save")).bold()
                        }
                    }
                    .disabled(isSaving || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: pickerItem) { newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        selectedImageData = data
                    }
                }
            }
        }
    }

    private func saveProfile() {
        isSaving = true
        errorMessage = nil

        let bw = Double(bodyweightInput.replacingOccurrences(of: ",", with: "."))
        let height = Double(heightInput.replacingOccurrences(of: ",", with: "."))
        let age = Int(ageInput.trimmingCharacters(in: .whitespaces))
        let bioText = bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bio

        Task {
            var finalAvatarURL: String? = avatarURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : avatarURL
            if let imageData = selectedImageData {
                if let uploaded = await service.uploadAvatar(imageData: imageData) {
                    finalAvatarURL = uploaded
                }
            }

            let success = await service.updateFullProfile(
                displayName: displayName,
                sex: sex,
                bodyweightKg: bw,
                avatarURL: finalAvatarURL,
                bio: bioText,
                heightCm: height,
                ageYears: age
            )
            isSaving = false
            if success {
                dismiss()
            } else {
                errorMessage = L10n.t("保存失败，请稍后重试", "Failed to save, please try again")
            }
        }
    }
}

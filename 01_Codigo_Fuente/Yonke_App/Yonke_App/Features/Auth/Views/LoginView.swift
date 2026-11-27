import SwiftUI

// MARK: - LoginView
/// Sign-in screen. Uses semantic text styles (Dynamic Type), content types for
/// password managers, keyboard focus chaining, and a single primary action.

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var showPassword = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email
        case password
    }

    private var canSubmit: Bool {
        !viewModel.isLoading && !viewModel.email.isEmpty && !viewModel.password.isEmpty
    }

    var body: some View {
        ZStack {
            YonkeTheme.background.ignoresSafeArea()

            // Decorative glow, hidden from VoiceOver.
            VStack {
                Circle()
                    .fill(YonkeTheme.accentRed.opacity(0.12))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(y: -80)
                    .accessibilityHidden(true)
                Spacer()
            }

            ScrollView {
                VStack(spacing: 32) {
                    header
                    loginForm
                    footer
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .background(YonkeTheme.accentRed.opacity(0.12), in: .circle)
                .accessibilityHidden(true)

            Text("\(Text("Yonke").foregroundStyle(YonkeTheme.accentRed))\(Text("App").foregroundStyle(YonkeTheme.textPrimary))")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text("Gestión de Inventario y Vehículos")
                .font(.subheadline)
                .foregroundStyle(YonkeTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Form

    private var loginForm: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Ingresa a tu cuenta")
                .font(.title3.bold())
                .foregroundStyle(YonkeTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)

            inputField(title: "Correo electrónico", icon: "envelope.fill") {
                TextField("ejemplo@correo.com", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focusedField, equals: .email)
                    .onSubmit { focusedField = .password }
                    .foregroundStyle(YonkeTheme.textPrimary)
            }

            inputField(title: "Contraseña", icon: "lock.fill") {
                Group {
                    if showPassword {
                        TextField("Ingresa tu contraseña", text: $viewModel.password)
                    } else {
                        SecureField("Ingresa tu contraseña", text: $viewModel.password)
                    }
                }
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($focusedField, equals: .password)
                .onSubmit {
                    if canSubmit { signIn() }
                }
                .foregroundStyle(YonkeTheme.textPrimary)

                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(YonkeTheme.textSecondary)
                .accessibilityLabel(showPassword ? "Ocultar contraseña" : "Mostrar contraseña")
            }

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(YonkeTheme.accentRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: signIn) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Iniciando sesión")
                } else {
                    Text("Iniciar sesión")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(YonkeTheme.accentRed)
            .disabled(!canSubmit)
            .padding(.top, 8)
        }
        .padding(24)
        .yonkeCard(cornerRadius: 16)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 4) {
            Text("Acceso Restringido a Personal Autorizado")
                .font(.caption.bold())
                .foregroundStyle(YonkeTheme.textSecondary)
            Text("Desarrollado para YonkeApp • 2026")
                .font(.caption)
                .foregroundStyle(YonkeTheme.textMuted)
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Helpers

    private func signIn() {
        guard canSubmit else { return }
        focusedField = nil
        Task { await viewModel.login() }
    }

    private func inputField<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.bold())
                .foregroundStyle(YonkeTheme.textSecondary)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(YonkeTheme.textMuted)
                    .frame(width: 20)
                    .accessibilityHidden(true)
                content()
            }
            .padding(14)
            .yonkeCard(cornerRadius: 10)
        }
    }
}

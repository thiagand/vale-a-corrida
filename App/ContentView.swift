import SwiftUI
import ReplayKit
import UserNotifications

/// Fase 0: prova que (1) o app instala, (2) a transmissão de tela liga o Leitor,
/// (3) o Leitor consegue ler texto da tela e (4) soltar notificação sem você tocar no celular.
struct ContentView: View {
    @State private var permissao: String = "verificando…"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("VALE A CORRIDA")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                    Text("Fase 0 · teste do leitor de ofertas")
                        .foregroundStyle(.secondary)
                }

                passo(1, "Permitir notificações", detalhe: "Situação: \(permissao)") {
                    Button("Permitir notificações") { pedirPermissao() }
                        .buttonStyle(.borderedProminent)
                }

                passo(2, "Ligar o leitor", detalhe: "Toque no botão abaixo, escolha \"Leitor de Ofertas\" e toque em Iniciar Transmissão. O indicador vermelho aparece no topo.") {
                    BroadcastButton()
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(Color.accentColor.opacity(0.15)))
                }

                passo(3, "Abrir a Uber", detalhe: "Com o leitor ligado, abra o app da Uber. A cada valor em R$ que aparecer na tela, chega uma notificação dizendo o que foi lido.") { EmptyView() }

                passo(4, "Desligar", detalhe: "Toque no indicador vermelho no topo da tela e em Parar.") { EmptyView() }

                Text("Este app de teste não envia nada para a internet. A leitura acontece no próprio iPhone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .onAppear { atualizarPermissao() }
    }

    @ViewBuilder
    private func passo<Conteudo: View>(_ n: Int, _ titulo: String, detalhe: String, @ViewBuilder conteudo: () -> Conteudo) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.system(.headline, design: .monospaced))
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 8) {
                Text(titulo).font(.headline)
                Text(detalhe).font(.subheadline).foregroundStyle(.secondary)
                conteudo()
            }
        }
    }

    private func pedirPermissao() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            atualizarPermissao()
        }
    }

    private func atualizarPermissao() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            let texto: String
            switch s.authorizationStatus {
            case .authorized, .provisional, .ephemeral: texto = "permitido ✓"
            case .denied: texto = "negado (libere em Ajustes › Notificações)"
            default: texto = "ainda não pedido"
            }
            DispatchQueue.main.async { permissao = texto }
        }
    }
}

/// Botão oficial do iOS que abre a escolha de transmissão, já apontando para o nosso Leitor.
struct BroadcastButton: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let v = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 64, height: 64))
        v.preferredExtension = (Bundle.main.bundleIdentifier ?? "com.thiagand.valeacorrida") + ".leitor"
        v.showsMicrophoneButton = false
        return v
    }
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

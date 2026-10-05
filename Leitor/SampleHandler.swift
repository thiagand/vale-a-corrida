import ReplayKit
import Vision
import CoreImage
import UserNotifications

/// Leitor de ofertas (Fase 0).
/// Recebe as imagens da tela durante a transmissão, lê o texto a cada ~2 s
/// e solta uma notificação quando encontra um valor em R$ novo.
/// Tudo acontece no iPhone; nada é enviado para fora.
final class SampleHandler: RPBroadcastSampleHandler {

    private let fila = DispatchQueue(label: "leitor.ocr", qos: .userInitiated)
    private var ocupado = false
    private var ultimaLeitura = Date.distantPast
    private var ultimoTextoAvisado = ""
    private let intervalo: TimeInterval = 2.0
    private let ciContext = CIContext(options: [.cacheIntermediates: false])

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        avisar(titulo: "Leitor ligado", corpo: "Abra a Uber. Vou avisar cada valor que eu ler na tela.")
    }

    override func broadcastFinished() {
        avisar(titulo: "Leitor desligado", corpo: "Transmissão encerrada.")
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
        let agora = Date()
        guard !ocupado, agora.timeIntervalSince(ultimaLeitura) >= intervalo,
              let pixel = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        ultimaLeitura = agora
        ocupado = true

        // Reduz a imagem para economizar memória (a extensão tem limite de ~50 MB).
        let original = CIImage(cvPixelBuffer: pixel)
        let escala = min(1.0, 900.0 / max(original.extent.width, 1))
        let reduzida = original.transformed(by: CGAffineTransform(scaleX: escala, y: escala))
        guard let cg = ciContext.createCGImage(reduzida, from: reduzida.extent) else { ocupado = false; return }

        fila.async { [weak self] in
            self?.ler(cg)
            self?.ocupado = false
        }
    }

    private func ler(_ imagem: CGImage) {
        let pedido = VNRecognizeTextRequest()
        pedido.recognitionLevel = .accurate
        pedido.recognitionLanguages = ["pt-BR"]
        pedido.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: imagem, options: [:])
        do { try handler.perform([pedido]) } catch { return }
        let linhas = (pedido.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        let achados = linhas.filter { $0.contains("R$") }
        guard !achados.isEmpty else { return }

        let resumo = achados.prefix(4).joined(separator: " · ")
        guard resumo != ultimoTextoAvisado else { return }
        ultimoTextoAvisado = resumo
        avisar(titulo: "Li na tela", corpo: resumo)
    }

    private func avisar(titulo: String, corpo: String) {
        let c = UNMutableNotificationContent()
        c.title = titulo
        c.body = corpo
        c.sound = .default
        if #available(iOS 15.0, *) { c.interruptionLevel = .timeSensitive }
        let r = UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil)
        UNUserNotificationCenter.current().add(r, withCompletionHandler: nil)
    }
}

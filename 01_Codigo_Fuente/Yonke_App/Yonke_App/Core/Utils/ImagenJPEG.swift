import UIKit

/// Reduce y comprime fotos antes de subirlas. Las fotos de celular pesan 3 a 8 MB;
/// con 2048 px de lado mayor y calidad 0.8 quedan en 0.5 a 1.5 MB.
enum ImagenJPEG {

    static func datos(desde imagen: UIImage, ladoMaximo: CGFloat = 2048, calidad: CGFloat = 0.8) -> Data? {
        let original = imagen.size
        let mayor = max(original.width, original.height)
        guard mayor > 0 else { return nil }

        let escala = min(1, ladoMaximo / mayor)
        let destino = CGSize(width: original.width * escala, height: original.height * escala)

        let formato = UIGraphicsImageRendererFormat.default()
        formato.scale = 1
        let renderer = UIGraphicsImageRenderer(size: destino, format: formato)
        let reducida = renderer.image { _ in
            imagen.draw(in: CGRect(origin: .zero, size: destino))
        }
        return reducida.jpegData(compressionQuality: calidad)
    }
}

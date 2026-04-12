import Foundation

struct Category: Identifiable, Hashable {
    let id: String
    let name: String
    let systemImage: String
    let folderName: String
    let fileExtensions: Set<String>

    static let images = Category(id: "images", name: "Bilder", systemImage: "photo", folderName: "Bilder", fileExtensions: ["jpg", "jpeg", "png", "gif", "heic", "webp", "tiff", "bmp", "svg"])
    static let documents = Category(id: "documents", name: "Dokumente", systemImage: "doc.text", folderName: "Dokumente", fileExtensions: ["pdf", "doc", "docx", "txt", "rtf", "md", "pages", "numbers", "key", "xls", "xlsx", "ppt", "pptx", "csv"])
    static let archives = Category(id: "archives", name: "Archive", systemImage: "archivebox", folderName: "Archive", fileExtensions: ["zip", "rar", "7z", "tar", "gz", "bz2", "xz"])
    static let audio = Category(id: "audio", name: "Audio", systemImage: "waveform", folderName: "Audio", fileExtensions: ["mp3", "m4a", "wav", "aiff", "flac", "aac", "ogg"])
    static let videos = Category(id: "videos", name: "Videos", systemImage: "film", folderName: "Videos", fileExtensions: ["mp4", "mov", "m4v", "avi", "mkv", "webm"])
    static let apps = Category(id: "apps", name: "Apps", systemImage: "app", folderName: "Apps", fileExtensions: ["app", "dmg", "pkg"])
    static let other = Category(id: "other", name: "Sonstiges", systemImage: "questionmark.folder", folderName: "Sonstiges", fileExtensions: [])

    static let all: [Category] = [.images, .documents, .archives, .audio, .videos, .apps, .other]
}

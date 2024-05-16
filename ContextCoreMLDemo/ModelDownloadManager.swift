import Foundation
import CoreML

class ModelDownloadManager {
    private let fileManager: FileManager
    private let modelsFolder: URL
    private let modelUpdateCheckURL = "https://krausefx.github.io/CoreMLDemo/latest_model_details.json"

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let folder = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("context_sdk_models") {
            self.modelsFolder = folder
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        } else {
            fatalError("Unable to find or create models folder.") // Handle this more gracefully
        }
    }
    
    internal func latestModel() -> MyFirstCustomModel? {
        let fileManagerContents = (try? fileManager.contentsOfDirectory(at: modelsFolder, includingPropertiesForKeys: nil)) ?? []
        
        // Try to find the latest model file based on modification date
        if let latestFileURL = fileManagerContents.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }).first,
            let otaModel = try? MyFirstCustomModel(contentsOf: latestFileURL) {
            return otaModel
        } else if let bundledModel = try? MyFirstCustomModel(configuration: MLModelConfiguration()) {
            return bundledModel // Fallback to the bundled model if no downloaded model exists
        }
        return nil
    }
    
    internal func checkForModelUpdates() async throws {
        guard let url = URL(string: modelUpdateCheckURL) else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelDownloadURLString = jsonObject["url"] as? String,
              let modelDownloadURL = URL(string: modelDownloadURLString) else {
            throw URLError(.cannotParseResponse)
        }
        
        try await downloadIfNeeded(from: modelDownloadURL)
    }
    
    private func downloadIfNeeded(from url: URL) async throws {
        let lastPathComponent = url.lastPathComponent
        
        // Check if the model file already exists (for this sample project we use the unique file name as identifier)
        if let localFiles = try? fileManager.contentsOfDirectory(at: modelsFolder, includingPropertiesForKeys: nil),
           localFiles.contains(where: { $0.lastPathComponent == lastPathComponent }) {
            // File exists, you could add a version check here if versions are part of the file name or metadata
            print("Model already exists locally. No need to download.")
        } else {
            let downloadedURL = try await downloadCoreMLFile(from: url) // File does not exist, download it
            _ = try compileCoreMLFile(at: downloadedURL)
            print("Model downloaded and compiled successfully.")
        }
    }
    
    // It's important to immediately move the downloaded CoreML file into a permanent location
    private func downloadCoreMLFile(from url: URL) async throws -> URL {
        let (tempLocalURL, _) = try await URLSession.shared.download(for: URLRequest(url: url))
        let destinationURL = modelsFolder.appendingPathComponent(tempLocalURL.lastPathComponent)
        try fileManager.moveItem(at: tempLocalURL, to: destinationURL)        
        return destinationURL
    }
    
    private func compileCoreMLFile(at localFilePath: URL) throws -> URL {
        let compiledModelURL = try MLModel.compileModel(at: localFilePath)
        let destinationCompiledURL = modelsFolder.appendingPathComponent(compiledModelURL.lastPathComponent)
        try fileManager.moveItem(at: compiledModelURL, to: destinationCompiledURL)
        try fileManager.removeItem(at: localFilePath)
        return destinationCompiledURL
    }
    
    private func deleteAllOutdatedModels(keeping recentModelFileName: String) throws {
        let urlContent = try fileManager.contentsOfDirectory(at: modelsFolder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        for fileURL in urlContent where fileURL.lastPathComponent != recentModelFileName {
            try fileManager.removeItem(at: fileURL)
        }
    }
}

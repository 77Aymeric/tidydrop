import Foundation

struct AppSettings: Hashable {
    var mode: RunMode = .copy
    var outputFolder = ""
    var includeSubfolders = true
    var ignoredExtensions = ".tmp, .DS_Store"
    var maxFileSizeMB = 50
    var confidenceThreshold = 0.75
    var suggestRenaming = true
    var applyRenaming = true
    var allowAICategories = true
    var fastModel = ""
    var expertTextModel = ""
    var expertVisionModel = ""
    var expertReviewEnabled = true
    var expertReviewThreshold = 0.80
    var aiTimeoutSeconds = 120
}

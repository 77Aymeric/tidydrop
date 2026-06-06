import Foundation

struct SortingTemplate: Identifiable, Hashable {
    var id: String
    var name: String
    var categories: [Category]

    static let all: [SortingTemplate] = [
        SortingTemplate(
            id: "downloads-cleanup",
            name: "Downloads Cleanup",
            categories: [
                Category(id: "documents", name: "Documents", description: "PDFs, office files, notes and useful references", rules: ""),
                Category(id: "images", name: "Images", description: "Pictures, screenshots and visual assets", rules: ""),
                Category(id: "archives", name: "Archives", description: "ZIP, RAR, 7Z, TAR and compressed downloads", rules: ""),
                Category(id: "installers", name: "Installers", description: "Apps, packages, disk images and setup files", rules: ""),
                Category(id: "review", name: "To Review", description: "Ambiguous files that need manual review", rules: "Use this when confidence is low.")
            ]
        ),
        SortingTemplate(
            id: "student-mode",
            name: "Student Mode",
            categories: [
                Category(id: "courses", name: "Courses", description: "Lecture slides, PDFs, class notes and handouts", rules: ""),
                Category(id: "assignments", name: "Assignments", description: "Homework, labs, reports and project submissions", rules: ""),
                Category(id: "exams", name: "Exams", description: "Past exams, quizzes, corrections and revision material", rules: ""),
                Category(id: "code", name: "Code", description: "Programming assignments, scripts and notebooks", rules: ""),
                Category(id: "review", name: "To Review", description: "Ambiguous school files", rules: "Use this when confidence is low.")
            ]
        ),
        SortingTemplate(
            id: "developer-mode",
            name: "Developer Mode",
            categories: [
                Category(id: "source-code", name: "Source Code", description: "Application code, scripts and snippets", rules: ""),
                Category(id: "config", name: "Config", description: "JSON, YAML, env samples, project and build configuration", rules: ""),
                Category(id: "docs", name: "Documentation", description: "Markdown, PDFs, notes and API references", rules: ""),
                Category(id: "assets", name: "Assets", description: "Images, icons, media and design exports", rules: ""),
                Category(id: "review", name: "To Review", description: "Ambiguous developer files", rules: "Use this when confidence is low.")
            ]
        ),
        SortingTemplate(
            id: "photo-cleanup",
            name: "Photo Cleanup",
            categories: [
                Category(id: "keepers", name: "Keepers", description: "Clear, useful or high-quality photos", rules: ""),
                Category(id: "blurry", name: "Blurry", description: "Blurred, badly framed or failed shots", rules: ""),
                Category(id: "screenshots", name: "Screenshots", description: "Phone and computer screenshots", rules: ""),
                Category(id: "documents", name: "Document Photos", description: "Photos of papers, invoices, whiteboards or forms", rules: ""),
                Category(id: "review", name: "To Review", description: "Ambiguous images", rules: "Use this when confidence is low.")
            ]
        ),
        SortingTemplate(
            id: "admin-papers",
            name: "Admin Papers",
            categories: [
                Category(id: "invoices", name: "Invoices", description: "Invoices, receipts and payment proofs", rules: ""),
                Category(id: "identity", name: "Identity", description: "Identity, insurance, bank and official documents", rules: ""),
                Category(id: "contracts", name: "Contracts", description: "Contracts, leases, agreements and signed papers", rules: ""),
                Category(id: "taxes", name: "Taxes", description: "Tax forms, declarations and fiscal documents", rules: ""),
                Category(id: "review", name: "To Review", description: "Ambiguous administrative papers", rules: "Use this when confidence is low.")
            ]
        )
    ]
}

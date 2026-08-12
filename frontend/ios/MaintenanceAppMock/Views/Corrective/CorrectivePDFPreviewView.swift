import SwiftUI

/// Compatibility entry point for corrective report versions.
/// The shared viewer reads the immutable version snapshot from the API.
struct CorrectivePDFPreviewView: View {
    let versionID: String

    var body: some View {
        PDFPreviewView(versionID: versionID)
    }
}

struct CorrectivePDFPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CorrectivePDFPreviewView(versionID: "report-version")
                .environmentObject(SessionStore())
        }
    }
}

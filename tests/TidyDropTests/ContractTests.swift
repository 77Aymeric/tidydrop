import Foundation
import XCTest
@testable import TidyDrop

final class ContractTests: XCTestCase {
    func testScanResponseDecodesBackendContract() throws {
        let json = """
        {
          "scan_id": "scan-123",
          "files": [],
          "summary": {
            "total_files": 0,
            "images": 0,
            "pdfs": 0,
            "documents": 0,
            "text": 0,
            "code": 0,
            "archives": 0,
            "media": 0,
            "unsupported": 0
          }
        }
        """
        let response = try JSONDecoder().decode(ScanResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.scanID, "scan-123")
        XCTAssertEqual(response.summary.totalFiles, 0)
    }

    func testOperationPlanDecodesServerSidePlanIdentifier() throws {
        let json = """
        {
          "plan_id": "plan-123",
          "run_id": "run-123",
          "created_at": "2026-06-15T12:00:00+02:00",
          "source_folder": "/tmp/source",
          "output_folder": "/tmp/output",
          "mode": "copy",
          "operations": []
        }
        """
        let plan = try JSONDecoder().decode(OperationPlan.self, from: Data(json.utf8))
        XCTAssertEqual(plan.planID, "plan-123")
        XCTAssertEqual(plan.mode, .copy)
    }
}

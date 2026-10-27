import XCTest
@testable import IslandCore

private actor WorkCount {
    var active = 0
    var peak = 0
    var completed = 0
    func begin() { active += 1; peak = max(peak, active) }
    func end() { active -= 1; completed += 1 }
    func result() -> (Int, Int) { (peak, completed) }
}
final class PermitTests: XCTestCase {
    func testConcurrentFanoutIsBounded() async throws {
        let pool = AsyncPermitPool(limit: 3)
        let count = WorkCount()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<30 {
                group.addTask {
                    try await pool.acquire()
                    await count.begin()
                    try await Task.sleep(nanoseconds: 1_000_000)
                    await count.end()
                    await pool.release()
                }
            }
            try await group.waitForAll()
        }
        let (peak, completed) = await count.result()
        XCTAssertLessThanOrEqual(peak, 3)
        XCTAssertEqual(completed, 30)
    }
    func testCancelledWaiterDoesNotLeakPermit() async throws {
        let pool = AsyncPermitPool(limit: 1)
        try await pool.acquire()
        let waiting = Task { try await pool.acquire() }
        await Task.yield()
        waiting.cancel()
        await pool.release()
        do { try await waiting.value; XCTFail("Cancelled request acquired a permit") }
        catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
        try await pool.acquire()
        await pool.release()
    }
}

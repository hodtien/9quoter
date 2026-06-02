import Foundation
import Testing
@testable import _QuoterApp

struct ModelsDecodingTests {
    @Test("Decodes Codex quota response")
    func decodesCodexQuota() throws {
        let data = Data(#"""
        {
          "plan": "plus",
          "limitReached": false,
          "reviewLimitReached": false,
          "quotas": {
            "session": { "used": 2, "total": 100, "remaining": 98, "resetAt": "2026-05-31T05:25:07.000Z", "unlimited": false },
            "weekly": { "used": 48, "total": 100, "remaining": 52, "resetAt": "2026-05-31T09:55:05.000Z", "unlimited": false }
          }
        }
        """#.utf8)

        let response = try JSONDecoder().decode(UsageResponse.self, from: data)

        #expect(response.plan == "plus")
        #expect(response.limitReached == false)
        #expect(response.reviewLimitReached == false)
        #expect(response.quotas?["session"]?.remaining == 98)
    }

    @Test("Decodes GitHub quota response with unlimited quota")
    func decodesGithubQuota() throws {
        let data = Data(#"""
        {
          "plan": "individual",
          "resetDate": "2026-06-01",
          "quotas": {
            "chat": { "used": 0, "total": 0, "remaining": 0, "unlimited": true, "resetAt": "2026-06-01T00:00:00.000Z" },
            "premium_interactions": { "used": 301, "total": 300, "remaining": -1, "unlimited": false, "resetAt": "2026-06-01T00:00:00.000Z" }
          }
        }
        """#.utf8)

        let response = try JSONDecoder().decode(UsageResponse.self, from: data)

        #expect(response.resetDate == "2026-06-01")
        #expect(response.quotas?["chat"]?.unlimited == true)
        #expect(response.quotas?["premium_interactions"]?.remaining == -1)
    }

    @Test("Decodes Kiro quota response with decimal usage")
    func decodesKiroQuota() throws {
        let data = Data(#"""
        {
          "plan": "KIRO PRO",
          "quotas": {
            "credit": { "used": 921.6, "total": 1000, "remaining": 78.39999999999998, "resetAt": "2026-06-01T00:00:00.000Z", "unlimited": false }
          }
        }
        """#.utf8)

        let response = try JSONDecoder().decode(UsageResponse.self, from: data)

        #expect(response.plan == "KIRO PRO")
        #expect(response.quotas?["credit"]?.used == 921.6)
        #expect(response.quotas?["credit"]?.remaining == 78.39999999999998)
    }

    @Test("Decodes Minimax remaining percentage as Double")
    func decodesMinimaxQuotaPercentage() throws {
        let data = Data(#"""
        {
          "quotas": {
            "MiniMax M* (5h)": { "used": 254, "total": 4500, "remaining": 4246, "remainingPercentage": 94.35555555555555, "resetAt": "2026-05-31T05:00:00.332Z", "unlimited": false },
            "MiniMax M* (7d)": { "used": 27102, "total": 45000, "remaining": 17898, "remainingPercentage": 39.77333333333333, "resetAt": "2026-06-01T00:00:00.332Z", "unlimited": false }
          }
        }
        """#.utf8)

        let response = try JSONDecoder().decode(UsageResponse.self, from: data)

        #expect(response.quotas?["MiniMax M* (5h)"]?.remainingPercentage == 94.35555555555555)
        #expect(response.quotas?["MiniMax M* (7d)"]?.remainingPercentage == 39.77333333333333)
    }

    @Test("Decodes provider client pagination")
    func decodesProviderClientPagination() throws {
        let data = Data(#"""
        {
          "connections": [
            { "id": "codex-1", "provider": "codex", "name": "first@example.com", "isActive": true, "testStatus": "success", "priority": 1, "iconURL": "/assets/codex.png" },
            { "id": "codex-2", "provider": "codex", "name": "second@example.com", "isActive": false, "testStatus": "success", "priority": 2, "iconUrl": "https://example.com/codex.png" }
          ],
          "pagination": { "page": 1, "pageSize": 100, "total": 156, "totalPages": 2 },
          "providerOptions": ["codex"]
        }
        """#.utf8)

        let response = try JSONDecoder().decode(ClientListResponse.self, from: data)

        #expect(response.connections.count == 2)
        #expect(response.connections[0].iconURL == "/assets/codex.png")
        #expect(response.connections[1].iconURL == "https://example.com/codex.png")
        #expect(response.pagination?.totalPages == 2)
        #expect(response.pagination?.total == 156)
    }

    @Test("Decodes usage stats recent requests")
    func decodesRecentRequests() throws {
        let data = Data(#"""
        {
          "recentRequests": [
            { "timestamp": "2026-05-31T04:10:00.000Z", "model": "claude-sonnet-4", "provider": "anthropic-compatible-freecc", "promptTokens": 1200, "completionTokens": 300, "status": "success" },
            { "timestamp": "2026-05-31T04:09:00.000Z", "model": "gpt-4.1", "provider": "github", "promptTokens": 80, "completionTokens": 12, "status": "error" }
          ]
        }
        """#.utf8)

        let response = try JSONDecoder().decode(RecentUsageStatsResponse.self, from: data)

        #expect(response.recentRequests.count == 2)
        #expect(response.recentRequests[0].model == "claude-sonnet-4")
        #expect(response.recentRequests[0].promptTokens == 1200)
        #expect(response.recentRequests[1].status == "error")
    }

    @Test("Decodes usage stream recent requests")
    func decodesRecentStreamRequests() throws {
        let data = Data(#"""
        {
          "activeRequests": [],
          "recentRequests": [
            { "timestamp": "2026-05-31T04:10:00.000Z", "model": "claude-sonnet-4", "provider": "anthropic-compatible-freecc", "promptTokens": 1200, "completionTokens": 300, "status": "success" }
          ],
          "pending": false
        }
        """#.utf8)

        let event = try JSONDecoder().decode(RecentUsageStreamEvent.self, from: data)

        #expect(event.recentRequests?.count == 1)
        #expect(event.recentRequests?.first?.model == "claude-sonnet-4")
    }

    @Test("Keeps only fixed latest 30 recent requests")
    func fixedRecentRequestLimitIsThirty() {
        let requests = (0..<35).map { index in
            RecentRequest(
                timestamp: "2026-05-31T04:\(String(format: "%02d", index % 60)):00.000Z",
                model: "model-\(index)",
                provider: "provider",
                promptTokens: index,
                completionTokens: index + 1,
                status: "success"
            )
        }

        #expect(Array(requests.prefix(RecentUsageStatsResponse.displayLimit)).count == 30)
    }

    @Test("Merges stream recent requests into existing snapshot")
    func mergesStreamRecentRequestsIntoSnapshot() {
        let existing = (0..<30).map { index in
            RecentRequest(
                timestamp: "2026-05-31T04:\(String(format: "%02d", index % 60)):00.000Z",
                model: "model-\(index)",
                provider: "provider",
                promptTokens: index,
                completionTokens: index + 1,
                status: "success"
            )
        }
        let incoming = [
            RecentRequest(
                timestamp: "2026-05-31T05:00:00.000Z",
                model: "new-model",
                provider: "codex",
                promptTokens: 10,
                completionTokens: 20,
                status: "success"
            ),
            existing[0]
        ]

        let merged = RecentRequestMerger.merged(incoming, into: existing)

        #expect(merged.count == 30)
        #expect(merged.first?.model == "new-model")
        #expect(merged.filter { $0.model == existing[0].model }.count == 1)
    }
}

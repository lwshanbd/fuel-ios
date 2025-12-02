import Foundation

/// Token usage information from LLM API
struct TokenUsage {
    let inputTokens: Int
    let outputTokens: Int
    let provider: String  // "Claude" or "ChatGPT"

    var totalTokens: Int {
        inputTokens + outputTokens
    }
}

/// Response structure for parsed fuel receipt data
struct FuelReceiptData: Codable {
    let gallons: Double?
    let pricePerGallon: Double?
    let totalCost: Double?
    let date: String?  // Optional date string if found on receipt

    var isValid: Bool {
        // At least need gallons or totalCost to be useful
        return gallons != nil || totalCost != nil
    }
}

/// Combined result with receipt data and token usage
struct LLMParseResult {
    let receiptData: FuelReceiptData
    let tokenUsage: TokenUsage
}

/// Error types for LLM service
enum LLMError: Error, LocalizedError {
    case noAPIKey
    case invalidResponse
    case networkError(Error)
    case parsingError(String)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Please add your API key in Settings."
        case .invalidResponse:
            return "Invalid response from AI service."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parsingError(let message):
            return "Failed to parse response: \(message)"
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}

/// Service for calling LLM APIs (Claude and ChatGPT)
final class LLMService {
    static let shared = LLMService()

    private let apiKeyManager = APIKeyManager.shared

    private init() {}

    // MARK: - Public Methods

    /// Parse fuel receipt text using available LLM
    /// Prefers Claude if available, falls back to ChatGPT
    func parseFuelReceipt(ocrText: String) async throws -> LLMParseResult {
        // Try Claude first
        if apiKeyManager.hasAPIKey(for: .claude) {
            return try await parseWithClaude(ocrText: ocrText)
        }

        // Fall back to ChatGPT
        if apiKeyManager.hasAPIKey(for: .chatgpt) {
            return try await parseWithChatGPT(ocrText: ocrText)
        }

        throw LLMError.noAPIKey
    }

    /// Check if any LLM API key is configured
    var hasAnyAPIKey: Bool {
        apiKeyManager.hasAPIKey(for: .claude) || apiKeyManager.hasAPIKey(for: .chatgpt)
    }

    // MARK: - Claude API

    private func parseWithClaude(ocrText: String) async throws -> LLMParseResult {
        guard let apiKey = apiKeyManager.getAPIKey(for: .claude) else {
            throw LLMError.noAPIKey
        }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let prompt = buildPrompt(ocrText: ocrText)

        let body: [String: Any] = [
            "model": "claude-3-5-haiku-latest",
            "max_tokens": 256,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw LLMError.apiError(message)
            }
            throw LLMError.apiError("HTTP \(httpResponse.statusCode)")
        }

        // Parse Claude response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw LLMError.invalidResponse
        }

        // Extract token usage from Claude response
        var inputTokens = 0
        var outputTokens = 0
        if let usage = json["usage"] as? [String: Any] {
            inputTokens = usage["input_tokens"] as? Int ?? 0
            outputTokens = usage["output_tokens"] as? Int ?? 0
        }

        let receiptData = try parseJSONResponse(text)
        let tokenUsage = TokenUsage(inputTokens: inputTokens, outputTokens: outputTokens, provider: "Claude")

        return LLMParseResult(receiptData: receiptData, tokenUsage: tokenUsage)
    }

    // MARK: - ChatGPT API

    private func parseWithChatGPT(ocrText: String) async throws -> LLMParseResult {
        guard let apiKey = apiKeyManager.getAPIKey(for: .chatgpt) else {
            throw LLMError.noAPIKey
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let prompt = buildPrompt(ocrText: ocrText)

        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 256,
            "temperature": 0
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw LLMError.apiError(message)
            }
            throw LLMError.apiError("HTTP \(httpResponse.statusCode)")
        }

        // Parse ChatGPT response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw LLMError.invalidResponse
        }

        // Extract token usage from ChatGPT response
        var inputTokens = 0
        var outputTokens = 0
        if let usage = json["usage"] as? [String: Any] {
            inputTokens = usage["prompt_tokens"] as? Int ?? 0
            outputTokens = usage["completion_tokens"] as? Int ?? 0
        }

        let receiptData = try parseJSONResponse(text)
        let tokenUsage = TokenUsage(inputTokens: inputTokens, outputTokens: outputTokens, provider: "ChatGPT")

        return LLMParseResult(receiptData: receiptData, tokenUsage: tokenUsage)
    }

    // MARK: - Prompt Engineering

    private func buildPrompt(ocrText: String) -> String {
        return """
        You are a fuel receipt parser. Extract fuel purchase information from the following OCR text of a gas station receipt.

        OCR Text:
        ---
        \(ocrText)
        ---

        Extract and return ONLY a JSON object with these fields:
        - gallons: number of gallons purchased (float, null if not found)
        - pricePerGallon: price per gallon in dollars (float, null if not found)
        - totalCost: total amount paid in dollars (float, null if not found)
        - date: transaction date if visible (string in format "YYYY-MM-DD", null if not found)

        Rules:
        1. Look for values labeled as "gallons", "gal", "volume", etc.
        2. Look for unit price, price/gal, $/gal for price per gallon
        3. Look for "total", "amount", "sale" for total cost
        4. All monetary values should be in dollars (remove $ symbol)
        5. If a value cannot be confidently determined, use null
        6. Return ONLY the JSON object, no explanation or markdown

        Example output:
        {"gallons": 12.45, "pricePerGallon": 3.459, "totalCost": 43.06, "date": null}
        """
    }

    // MARK: - Response Parsing

    private func parseJSONResponse(_ text: String) throws -> FuelReceiptData {
        // Clean up the response - remove markdown code blocks if present
        var cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code blocks
        if cleanText.hasPrefix("```json") {
            cleanText = String(cleanText.dropFirst(7))
        } else if cleanText.hasPrefix("```") {
            cleanText = String(cleanText.dropFirst(3))
        }
        if cleanText.hasSuffix("```") {
            cleanText = String(cleanText.dropLast(3))
        }
        cleanText = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Find JSON object in the text
        guard let startIndex = cleanText.firstIndex(of: "{"),
              let endIndex = cleanText.lastIndex(of: "}") else {
            throw LLMError.parsingError("No JSON object found in response")
        }

        let jsonString = String(cleanText[startIndex...endIndex])

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw LLMError.parsingError("Failed to convert to data")
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(FuelReceiptData.self, from: jsonData)
        } catch {
            throw LLMError.parsingError(error.localizedDescription)
        }
    }
}

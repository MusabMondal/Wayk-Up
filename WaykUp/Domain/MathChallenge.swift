import Foundation

struct MathQuestion: Equatable, Sendable {
    enum Operation: String, CaseIterable, Sendable { case addition, multiplication }
    let left: Int
    let right: Int
    let operation: Operation
    var answer: Int { operation == .addition ? left + right : left * right }
    var prompt: String { "\(left) \(operation == .addition ? "+" : "×") \(right)" }
}

protocol MathQuestionGenerating {
    func makeQuestions(count: Int) -> [MathQuestion]
}

struct RandomMathQuestionGenerator: MathQuestionGenerating {
    func makeQuestions(count: Int) -> [MathQuestion] {
        (0..<count).map { _ in
            MathQuestion(left: .random(in: 1...12), right: .random(in: 1...12),
                         operation: Bool.random() ? .addition : .multiplication)
        }
    }
}

// A session owns progression; presentation and alarm services cannot bypass it.
struct MathChallengeSession {
    static let questionCount = 2
    private let questions: [MathQuestion]
    private(set) var completedCount = 0
    init(generator: any MathQuestionGenerating) {
        questions = generator.makeQuestions(count: Self.questionCount)
        precondition(questions.count == Self.questionCount)
    }
    var isComplete: Bool { completedCount == questions.count }
    var currentQuestion: MathQuestion? { isComplete ? nil : questions[completedCount] }
    @discardableResult mutating func submit(_ answer: Int) -> Bool {
        guard let question = currentQuestion, question.answer == answer else { return false }
        completedCount += 1
        return true
    }
}

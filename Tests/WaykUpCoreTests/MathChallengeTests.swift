import Testing
@testable import WaykUpCore

private struct FixedGenerator: MathQuestionGenerating {
    func makeQuestions(count: Int) -> [MathQuestion] {
        [MathQuestion(left: 3, right: 4, operation: .addition),
         MathQuestion(left: 6, right: 7, operation: .multiplication)]
    }
}
@Test func wrongAnswersNeverUnlockActions() {
    var session = MathChallengeSession(generator: FixedGenerator())
    let result1 = session.submit(8)
    #expect(!result1)
    #expect(session.completedCount == 0)
    #expect(!session.isComplete)
}
@Test func requiresExactlyTwoCorrectAnswers() {
    var session = MathChallengeSession(generator: FixedGenerator())
    let result2 = session.submit(7)
    #expect(result2)
    #expect(!session.isComplete)
    let result3 = session.submit(41)
    #expect(!result3)
    let result4 = session.submit(42)
    #expect(result4)
    #expect(session.isComplete)
    #expect(session.currentQuestion == nil)
    let result5 = session.submit(42)
    #expect(!result5)
    #expect(session.completedCount == 2)
}
@Test func newSessionResetsSnoozeChallenge() {
    var old = MathChallengeSession(generator: FixedGenerator())
    old.submit(7); old.submit(42)
    let fresh = MathChallengeSession(generator: FixedGenerator())
    #expect(old.isComplete)
    #expect(fresh.completedCount == 0)
    #expect(!fresh.isComplete)
}
@Test func generatedQuestionsStayWithinSimpleRange() {
    let questions = RandomMathQuestionGenerator().makeQuestions(count: 200)
    #expect(questions.count == 200)
    #expect(questions.allSatisfy { (1...12).contains($0.left) && (1...12).contains($0.right) })
}

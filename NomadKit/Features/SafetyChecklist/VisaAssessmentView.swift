import SwiftUI

struct VisaAssessmentQuestion: Identifiable, Hashable {
    enum Answer: String, CaseIterable, Hashable, Codable {
        case yes, unsure, no
    }

    let id: String
    let category: String
    let titleEN: String
    let titleZH: String
    let yesEN: String
    let yesZH: String
    let unsureEN: String
    let unsureZH: String
    let noEN: String
    let noZH: String
    let weight: Int
    let gapEN: String
    let gapZH: String

    func title(isChinese: Bool) -> String { isChinese ? titleZH : titleEN }
    func option(_ answer: Answer, isChinese: Bool) -> String {
        switch (answer, isChinese) {
        case (.yes, true): yesZH; case (.yes, false): yesEN
        case (.unsure, true): unsureZH; case (.unsure, false): unsureEN
        case (.no, true): noZH; case (.no, false): noEN
        }
    }
    func gap(isChinese: Bool) -> String { isChinese ? gapZH : gapEN }
}

struct VisaAssessmentResult: Codable, Hashable {
    let countryCode: String
    let score: Int
    let completedAt: Date
    let answers: [String: VisaAssessmentQuestion.Answer]

    var band: ClosedRange<Int> {
        switch score { case 80...100: 80...100; case 60..<80: 60...79; case 40..<60: 40...59; default: 0...39 }
    }
    var levelEN: String { score >= 80 ? "Strong starting point" : score >= 60 ? "Getting prepared" : score >= 40 ? "Some gaps to close" : "More preparation needed" }
    var levelZH: String { score >= 80 ? "准备度较高" : score >= 60 ? "正在准备" : score >= 40 ? "还有一些缺口" : "需要更多准备" }
}

enum VisaAssessmentCatalog {
    static func questions(for code: String) -> [VisaAssessmentQuestion] {
        let c = code.uppercased()
        var questions = [
            VisaAssessmentQuestion(id: "remote-work", category: "work", titleEN: "Can you show an ongoing remote-work, freelance, or overseas employment relationship?", titleZH: "你能证明自己有持续的远程工作、自由职业或海外雇佣关系吗？", yesEN: "Yes, I have current proof", yesZH: "有，我有近期证明", unsureEN: "I need to check my documents", unsureZH: "需要确认材料", noEN: "Not yet", noZH: "还没有", weight: 25, gapEN: "Prepare an employment contract, employer letter, or professional portfolio.", gapZH: "准备雇佣合同、雇主证明或专业作品集。"),
            VisaAssessmentQuestion(id: "funds", category: "funds", titleEN: "Do you meet the income or savings threshold described in this article?", titleZH: "你达到这篇文章中说明的收入或资金门槛吗？", yesEN: "Yes, with recent evidence", yesZH: "达到，有近期证明", unsureEN: "I need to calculate it", unsureZH: "需要重新计算", noEN: "Not yet", noZH: "还没有", weight: 25, gapEN: "Check the current threshold and collect recent bank, tax, or payslip evidence.", gapZH: "确认当前门槛，并准备近期银行、税务或工资证明。"),
            VisaAssessmentQuestion(id: "insurance", category: "documents", titleEN: "Do you have the required health or travel insurance coverage?", titleZH: "你有符合要求的健康或旅行保险吗？", yesEN: "Yes, coverage is current", yesZH: "有，保障有效", unsureEN: "I need to verify the coverage", unsureZH: "需要确认保障范围", noEN: "Not yet", noZH: "还没有", weight: 15, gapEN: "Obtain insurance that matches the destination's coverage and validity rules.", gapZH: "购买符合目的地保障范围和有效期要求的保险。"),
            VisaAssessmentQuestion(id: "core-documents", category: "documents", titleEN: "Can you provide the core documents listed for this visa?", titleZH: "你能提供该签证列出的核心材料吗？", yesEN: "Yes, most are ready", yesZH: "可以，大部分已准备", unsureEN: "I am still collecting them", unsureZH: "正在收集", noEN: "Not yet", noZH: "还没有", weight: 20, gapEN: "Use the article's document list as a checklist and verify formats with the mission.", gapZH: "把文章中的材料清单当作检查表，并向使领馆确认格式。"),
            VisaAssessmentQuestion(id: "special-rule", category: "eligibility", titleEN: "Have you checked the country-specific eligibility limits and restrictions?", titleZH: "你确认过该国特有的资格限制和工作规定吗？", yesEN: "Yes, I fit the rule", yesZH: "确认过，符合规定", unsureEN: "I need official confirmation", unsureZH: "需要官方确认", noEN: "Not yet", noZH: "还没有", weight: 15, gapEN: "Review the eligibility highlights and confirm any passport, local-work, or family rules.", gapZH: "复核资格要点，并确认护照、当地工作或家属相关规定。")
        ]
        if c == "JP" { questions[4] = VisaAssessmentQuestion(id: "special-rule", category: "eligibility", titleEN: "Is your passport eligible for Japan's listed digital nomad route?", titleZH: "你的护照属于日本数字游民签证列出的资格范围吗？", yesEN: "Yes, I confirmed the list", yesZH: "是的，已确认名单", unsureEN: "I need to check the list", unsureZH: "需要查看名单", noEN: "No", noZH: "不属于", weight: 15, gapEN: "Check the official nationality list before preparing the rest of the application.", gapZH: "先查看官方国籍名单，再准备其他申请材料。") }
        if c == "KR" { questions[4] = VisaAssessmentQuestion(id: "special-rule", category: "eligibility", titleEN: "Do you have at least one year of experience in the same industry and no Korean local employer?", titleZH: "你有至少一年同行业经验，且不会为韩国本地雇主工作吗？", yesEN: "Yes", yesZH: "符合", unsureEN: "I need to confirm", unsureZH: "需要确认", noEN: "No", noZH: "不符合", weight: 15, gapEN: "Confirm the one-year experience rule and the restriction on local profit-making work.", gapZH: "确认一年经验要求，以及不得从事韩国本地营利工作的限制。") }
        return questions
    }
}

struct VisaAssessmentView: View {
    let article: VisaArticle
    let onComplete: (VisaAssessmentResult) -> Void
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var answers: [String: VisaAssessmentQuestion.Answer] = [:]
    @State private var result: VisaAssessmentResult?

    private var isChinese: Bool { locale.identifier.hasPrefix("zh") }
    private var questions: [VisaAssessmentQuestion] { VisaAssessmentCatalog.questions(for: article.countryCode) }
    private var current: VisaAssessmentQuestion { questions[index] }

    var body: some View {
        Group {
            if let result { VisaAssessmentResultView(article: article, result: result, questions: questions) { dismiss() } }
            else { questionBody }
        }
        .background(Color.nomadBackground)
        .navigationTitle(isChinese ? "签证准备度测试" : "Visa readiness test")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var questionBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProgressView(value: Double(index + 1), total: Double(questions.count)).tint(Color.tone(article.tone)).padding(.horizontal, 20)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("\(index + 1) / \(questions.count)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(current.title(isChinese: isChinese)).font(.system(.title2, design: .rounded, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                    VStack(spacing: 10) {
                        ForEach(VisaAssessmentQuestion.Answer.allCases, id: \.self) { answer in
                            Button { answers[current.id] = answer } label: {
                                HStack { Text(current.option(answer, isChinese: isChinese)).font(.body.weight(.medium)); Spacer(); Image(systemName: answers[current.id] == answer ? "checkmark.circle.fill" : "circle").foregroundStyle(answers[current.id] == answer ? Color.tone(article.tone) : .secondary) }
                                    .padding(16).background(Color.nomadSurface, in: RoundedRectangle(cornerRadius: 10)).overlay { RoundedRectangle(cornerRadius: 10).stroke(answers[current.id] == answer ? Color.tone(article.tone) : .clear, lineWidth: 2) }
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(20)
            }
            HStack(spacing: 12) {
                if index > 0 { Button(isChinese ? "上一步" : "Back") { index -= 1 }.buttonStyle(.bordered) }
                Button(index == questions.count - 1 ? (isChinese ? "查看结果" : "See result") : (isChinese ? "下一步" : "Next")) { advance() }.buttonStyle(.borderedProminent).tint(Color.nomadInk).disabled(answers[current.id] == nil).frame(maxWidth: .infinity)
            }.padding(20)
        }
    }

    private func advance() {
        guard answers[current.id] != nil else { return }
        if index < questions.count - 1 { index += 1; return }
        let total = questions.reduce(0) { $0 + $1.weight }
        let points = questions.reduce(0) { partial, question in
            partial + Int(Double(question.weight) * (answers[question.id] == .yes ? 1 : answers[question.id] == .unsure ? 0.5 : 0))
        }
        let assessment = VisaAssessmentResult(countryCode: article.countryCode, score: Int((Double(points) / Double(total) * 100).rounded()), completedAt: .now, answers: answers)
        let data = try? JSONEncoder().encode(assessment); UserDefaults.standard.set(data, forKey: "visa.assessment.\(article.countryCode)")
        onComplete(assessment); result = assessment
    }
}

private struct VisaAssessmentResultView: View {
    let article: VisaArticle
    let result: VisaAssessmentResult
    let questions: [VisaAssessmentQuestion]
    let done: () -> Void
    @Environment(\.locale) private var locale
    private var isChinese: Bool { locale.identifier.hasPrefix("zh") }
    private var gaps: [VisaAssessmentQuestion] { questions.filter { result.answers[$0.id] != .yes } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: result.score >= 60 ? "checkmark.seal.fill" : "list.clipboard.fill").font(.system(size: 44)).foregroundStyle(Color.tone(article.tone))
                    Text(isChinese ? result.levelZH : result.levelEN).font(.title2.bold())
                    Text("\(result.band.lowerBound)–\(result.band.upperBound)%").font(.system(size: 38, weight: .bold, design: .rounded)).foregroundStyle(Color.tone(article.tone))
                    Text(isChinese ? "这是基于公开要求和你自报信息的准备度估算，不代表签证批准概率或法律意见。" : "This is a readiness estimate based on public requirements and your answers. It is not an approval probability or legal advice.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(20).background(Color.nomadSurface, in: RoundedRectangle(cornerRadius: 12))
                Text(isChinese ? "还需要确认" : "Items to review").font(.title3.bold())
                if gaps.isEmpty { Label(isChinese ? "核心条件都已标记为满足" : "You marked all core conditions as ready", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                ForEach(gaps) { question in Label(question.gap(isChinese: isChinese), systemImage: "arrow.right.circle").font(.subheadline).fixedSize(horizontal: false, vertical: true) }
                Button(isChinese ? "完成" : "Done", action: done).buttonStyle(.borderedProminent).tint(Color.nomadInk).frame(maxWidth: .infinity)
            }.padding(20)
        }
    }
}

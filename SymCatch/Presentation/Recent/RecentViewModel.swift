//
//  RecentViewModel.swift
//  SymCatch
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Domain

/// 최근 찾은 심볼(S5): 날짜 묶음, 이름 검색, 밀어서 삭제, 전체 삭제(기획서 2.4).
@MainActor @Observable
final class RecentViewModel {
    enum LoadState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    struct Section: Identifiable, Equatable {
        let group: RecentDateGroup
        let records: [FoundRecord]
        var id: RecentDateGroup { group }
    }

    private(set) var loadState: LoadState = .loading
    private(set) var records: [FoundRecord] = []
    private(set) var badges: [String: SymbolBadge] = [:]
    /// 이름 검색어
    var query = ""
    /// "전체 삭제" 확인 알림을 띄웠는지
    var isConfirmingClear = false

    private let fetchRecent: any FetchRecentRecordsUseCase
    private let deleteRecords: any DeleteRecordsUseCase
    private let clearHistory: any ClearHistoryUseCase
    private let fetchBadges: any FetchBadgesUseCase
    private weak var navigator: (any RecentNavigating)?
    private let now: () -> Date
    private let calendar: Calendar

    init(
        fetchRecent: any FetchRecentRecordsUseCase,
        deleteRecords: any DeleteRecordsUseCase,
        clearHistory: any ClearHistoryUseCase,
        fetchBadges: any FetchBadgesUseCase,
        navigator: (any RecentNavigating)?,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.fetchRecent = fetchRecent
        self.deleteRecords = deleteRecords
        self.clearHistory = clearHistory
        self.fetchBadges = fetchBadges
        self.navigator = navigator
        self.now = now
        self.calendar = calendar
    }

    // MARK: - 표시용 값

    /// 기록이 하나도 없음(빈 상태 화면)
    var hasNoHistory: Bool { loadState == .loaded && records.isEmpty }

    /// 검색어를 적용한 날짜 묶음
    var sections: [Section] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let matched = trimmed.isEmpty ? records : records.filter { $0.symbolName.localizedCaseInsensitiveContains(trimmed) }
        return RecentGroupingPolicy.grouped(matched, now: now(), calendar: calendar).map { Section(group: $0.group, records: $0.records) }
    }

    /// 기록은 있지만 검색 결과가 없음
    var hasNoSearchResults: Bool { !records.isEmpty && sections.isEmpty }

    func badge(for record: FoundRecord) -> SymbolBadge? {
        badges[record.symbolName]
    }

    /// 행의 시각: 오늘 "오후 1:52", 어제 "어제 오후 9:14", 그 외 "10월 7일"(디자인 S5)
    func timeText(for record: FoundRecord) -> String {
        let time = record.foundAt.formatted(date: .omitted, time: .shortened)
        switch RecentGroupingPolicy.group(of: record.foundAt, now: now(), calendar: calendar) {
        case .today: return time
        case .yesterday: return String(localized: "어제 \(time)")
        case .thisWeek, .earlier: return record.foundAt.formatted(.dateTime.month(.defaultDigits).day())
        }
    }

    // MARK: - 입력

    /// 화면이 보일 때마다 다시 읽는다(그리기 탭에서 새로 찾았을 수 있음).
    func load() async {
        do {
            records = try await fetchRecent.execute(limit: nil)
            badges = try await fetchBadges.execute()
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    func select(_ record: FoundRecord) {
        navigator?.showRecentDetail(SymbolDetailRequest(name: record.symbolName, sketch: record.sketch,
                                                        similarity: record.similarity, isPastSketch: true))
    }

    /// 밀어서 삭제. 목록에서 먼저 빼고, 저장에 실패하면 다시 읽어 되돌린다.
    func delete(_ record: FoundRecord) async {
        records.removeAll { $0.id == record.id }
        do {
            try await deleteRecords.execute(ids: [record.id])
        } catch {
            await load()
        }
    }

    func requestClearAll() {
        isConfirmingClear = true
    }

    /// 알림의 "모두 지우기". 기록(그림 포함)만 지우고 뱃지는 남긴다.
    func confirmClearAll() async {
        isConfirmingClear = false
        do {
            try await clearHistory.execute()
            records = []
        } catch {
            await load()
        }
    }

    /// 빈 상태의 "그리러 가기"
    func goDraw() {
        navigator?.showDrawTab()
    }
}

extension RecentDateGroup {
    var title: String {
        switch self {
        case .today: String(localized: "오늘")
        case .yesterday: String(localized: "어제")
        case .thisWeek: String(localized: "이번 주")
        case .earlier: String(localized: "이전")
        }
    }
}

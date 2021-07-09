import Foundation

public extension Date {
    func daysAgo(days: Int) -> Date? {
        var components = DateComponents()
        components.day = -days
        let newDate = Calendar.current.date(byAdding: components, to: self)
        return newDate
    }
}

import SwiftUI

struct LyricFocusVisualProgress: Equatable {
    let color: CGFloat
    let blur: CGFloat
}

struct LyricFocusColorTransition: Equatable, Identifiable {
    enum TimingCurve: Equatable {
        case smoothStep
        case cubicBezier(CGFloat, CGFloat, CGFloat, CGFloat)
        case physicalSpring(LyricPhysicalSpringParameters)
    }

    let id: UUID
    let initialColorProgressByID: [LyricLine.ID: CGFloat]
    let initialBlurProgressByID: [LyricLine.ID: CGFloat]
    let destinationLyricID: LyricLine.ID?
    let startedAt: Date
    let colorDuration: TimeInterval
    let blurDuration: TimeInterval
    let colorTimingCurve: TimingCurve
    let blurTimingCurve: TimingCurve

    init(
        id: UUID = UUID(),
        initialColorProgressByID: [LyricLine.ID: CGFloat],
        initialBlurProgressByID: [LyricLine.ID: CGFloat],
        destinationLyricID: LyricLine.ID?,
        startedAt: Date,
        colorDuration: TimeInterval,
        blurDuration: TimeInterval,
        colorTimingCurve: TimingCurve,
        blurTimingCurve: TimingCurve
    ) {
        self.id = id
        self.initialColorProgressByID = initialColorProgressByID.mapValues {
            Self.unitProgress($0)
        }
        self.initialBlurProgressByID = initialBlurProgressByID.mapValues {
            Self.unitProgress($0)
        }
        self.destinationLyricID = destinationLyricID
        self.startedAt = startedAt
        self.colorDuration = colorDuration.isFinite
            ? max(colorDuration, 0)
            : 0
        self.blurDuration = blurDuration.isFinite
            ? max(blurDuration, 0)
            : 0
        self.colorTimingCurve = colorTimingCurve
        self.blurTimingCurve = blurTimingCurve
    }

    var completionDate: Date {
        startedAt.addingTimeInterval(max(colorDuration, blurDuration))
    }

    func includes(_ lyricID: LyricLine.ID) -> Bool {
        initialColorProgressByID[lyricID] != nil
            || initialBlurProgressByID[lyricID] != nil
            || destinationLyricID == lyricID
    }

    func colorProgress(
        for lyricID: LyricLine.ID,
        at date: Date
    ) -> CGFloat {
        progress(
            for: lyricID,
            initialProgressByID: initialColorProgressByID,
            duration: colorDuration,
            timingCurve: colorTimingCurve,
            at: date
        )
    }

    func blurProgress(
        for lyricID: LyricLine.ID,
        at date: Date
    ) -> CGFloat {
        progress(
            for: lyricID,
            initialProgressByID: initialBlurProgressByID,
            duration: blurDuration,
            timingCurve: blurTimingCurve,
            at: date
        )
    }

    func presentationColorProgressByID(
        at date: Date
    ) -> [LyricLine.ID: CGFloat] {
        presentationProgressByID(at: date, usesBlurProgress: false)
    }

    func presentationBlurProgressByID(
        at date: Date
    ) -> [LyricLine.ID: CGFloat] {
        presentationProgressByID(at: date, usesBlurProgress: true)
    }

    private func presentationProgressByID(
        at date: Date,
        usesBlurProgress: Bool
    ) -> [LyricLine.ID: CGFloat] {
        var ids = Set(
            usesBlurProgress
                ? initialBlurProgressByID.keys
                : initialColorProgressByID.keys
        )
        if let destinationLyricID { ids.insert(destinationLyricID) }
        return ids.reduce(into: [:]) { result, id in
            let value = usesBlurProgress
                ? blurProgress(for: id, at: date)
                : colorProgress(for: id, at: date)
            if value > 0 { result[id] = value }
        }
    }

    private func progress(
        for lyricID: LyricLine.ID,
        initialProgressByID: [LyricLine.ID: CGFloat],
        duration: TimeInterval,
        timingCurve: TimingCurve,
        at date: Date
    ) -> CGFloat {
        let initial = initialProgressByID[lyricID, default: 0]
        let destination: CGFloat = destinationLyricID == lyricID ? 1 : 0
        let elapsed = max(date.timeIntervalSince(startedAt), 0)
        let normalized = Self.normalizedProgress(
            elapsed: elapsed,
            duration: duration,
            timingCurve: timingCurve
        )
        return Self.unitProgress(
            initial + (destination - initial) * normalized
        )
    }

    private static func normalizedProgress(
        elapsed: TimeInterval,
        duration: TimeInterval,
        timingCurve: TimingCurve
    ) -> CGFloat {
        guard duration > 0, elapsed < duration else { return 1 }
        let linear = unitProgress(CGFloat(elapsed / duration))
        switch timingCurve {
        case .smoothStep:
            return linear * linear * (3 - 2 * linear)
        case let .cubicBezier(x1, y1, x2, y2):
            return cubicBezierProgress(
                linear,
                controlPoint1X: x1,
                controlPoint1Y: y1,
                controlPoint2X: x2,
                controlPoint2Y: y2
            )
        case let .physicalSpring(parameters):
            let spring = Spring(
                mass: parameters.mass,
                stiffness: parameters.stiffness,
                damping: parameters.damping,
                allowOverDamping: true
            )
            let value = spring.value(
                target: 1,
                initialVelocity: 0,
                time: elapsed
            )
            return unitProgress(CGFloat(value))
        }
    }

    private static func cubicBezierProgress(
        _ linearProgress: CGFloat,
        controlPoint1X: CGFloat,
        controlPoint1Y: CGFloat,
        controlPoint2X: CGFloat,
        controlPoint2Y: CGFloat
    ) -> CGFloat {
        var lower: CGFloat = 0
        var upper: CGFloat = 1
        for _ in 0..<16 {
            let parameter = (lower + upper) * 0.5
            if cubicCoordinate(
                parameter,
                first: controlPoint1X,
                second: controlPoint2X
            ) < linearProgress {
                lower = parameter
            } else {
                upper = parameter
            }
        }
        return unitProgress(
            cubicCoordinate(
                (lower + upper) * 0.5,
                first: controlPoint1Y,
                second: controlPoint2Y
            )
        )
    }

    private static func cubicCoordinate(
        _ parameter: CGFloat,
        first: CGFloat,
        second: CGFloat
    ) -> CGFloat {
        let inverse = 1 - parameter
        return 3 * inverse * inverse * parameter * first
            + 3 * inverse * parameter * parameter * second
            + parameter * parameter * parameter
    }

    private static func unitProgress(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }
}

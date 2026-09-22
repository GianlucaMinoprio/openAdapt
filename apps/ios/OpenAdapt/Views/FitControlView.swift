import SwiftUI
import UIKit

struct FitControlView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { AdaptMotion.reduced(system: systemReduceMotion) }
    var body: some View {
        GeometryReader { geometry in
            let top: CGFloat = 98
            let travel = max(80, geometry.size.height - 195)
            ZStack {
                Rectangle().fill(store.canvasInk.opacity(0.06)).frame(width: 1).padding(.vertical, 50)
                HStack(spacing: 0) {
                    ForEach(ShoeSide.allCases) { side in
                        let foot = store.feet[side]!
                        let shown = foot.connected && foot.hasFitCalibration ? foot.dragPosition ?? Double(foot.target) : 35
                        let displacement = travel * (1 - CGFloat(shown) / 100)
                        ZStack(alignment: .top) {
                            VStack(spacing: 0) {
                                ForEach(0..<11) { index in
                                    Rectangle().fill(store.canvasInk.opacity(index % 5 == 0 ? 0.32 : 0.13))
                                        .frame(width: index % 5 == 0 ? 13 : 5, height: 1)
                                    if index != 10 { Spacer(minLength: 0) }
                                }
                            }.frame(width: 16, height: travel)
                                .position(x: side == .left ? 9 : geometry.size.width / 2 - 9, y: top + travel / 2)
                                .opacity(foot.connected && foot.hasFitCalibration ? 1 : 0)
                            // The selection follows the finger without lag, then
                            // holds its level while the separate lacing mark arrives.
                            RoundedRectangle(cornerRadius: 1).fill(store.canvasInk)
                                .frame(width: 28, height: 2)
                                .position(x: side == .left ? 14 : geometry.size.width / 2 - 14, y: top)
                                .offset(y: displacement)
                                .opacity(foot.connected && (foot.dragging || foot.lacing) ? (foot.lacing ? 0.35 : 1) : 0)
                                .animation(reduceMotion || foot.dragging || foot.directAdjustment ? nil : AdaptMotion.settle, value: shown)
                            FitProgressMark(foot: foot, ink: store.canvasInk, travel: travel)
                                .position(x: side == .left ? 12 : geometry.size.width / 2 - 12, y: top)
                                .opacity(foot.connected && foot.hasFitCalibration && !foot.dragging ? 0.95 : 0)
                            Text(side.letter)
                                .font(.system(size: min(230, geometry.size.width * 0.56), weight: .black).italic())
                                .fontWidth(.condensed).tracking(-14)
                                .foregroundStyle(store.canvasInk).opacity(foot.connected && foot.hasFitCalibration ? 1 : 0.16)
                                .animation(AdaptMotion.state, value: foot.connected)
                                .position(x: geometry.size.width / 4 - (side == .left ? -9 : 7), y: top)
                                .offset(y: displacement)
                                .animation(reduceMotion || foot.dragging || foot.directAdjustment ? nil : AdaptMotion.settle, value: shown)
                        }.frame(width: geometry.size.width / 2, height: geometry.size.height)
                    }
                }.accessibilityHidden(true)
                MultiTouchFitInput(feet: store.feet, travel: travel,
                                   change: store.change, commit: store.commit, cancel: store.cancelDrag,
                                   adjust: store.adjust, prepare: store.haptics.prepare)
            }
        }.frame(minHeight: 290).accessibilityIdentifier("fit-controls")
    }
}

/// Only this small mark redraws during lacing. No per-frame app-wide state writes.
private struct FitProgressMark: View {
    let foot: FootState
    let ink: Color
    let travel: CGFloat
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { AdaptMotion.reduced(system: systemReduceMotion) }
    var body: some View {
        TimelineView(.animation(paused: !foot.lacing || reduceMotion)) { timeline in
            let value = progress(at: timeline.date)
            RoundedRectangle(cornerRadius: 2).fill(ink).frame(width: 20, height: 3)
                .offset(y: travel * (1 - CGFloat(value) / 100))
                .animation(reduceMotion ? nil : AdaptMotion.settle, value: foot.lacing)
        }
    }
    private func progress(at date: Date) -> Double {
        guard !reduceMotion, foot.lacing, let started = foot.movementStartedAt else { return foot.progress }
        // This 2.8-second curve is a motor estimate, not a decorative UI transition.
        // Wait at 90% until the shoe confirms completion and position.
        let fraction = min(1, max(0, date.timeIntervalSince(started) / AdaptMotion.lacingEstimate)) * 0.9
        return foot.movementStart + (Double(foot.target) - foot.movementStart) * fraction
    }
}

/// One UIKit touch surface permits two independent fingers, including when they
/// cross the center. A finger retains ownership of the side where it began.
private struct MultiTouchFitInput: UIViewRepresentable {
    let feet: [ShoeSide: FootState]
    let travel: CGFloat
    let change: (ShoeSide, Double) -> Void
    let commit: (ShoeSide) -> Void
    let cancel: ([ShoeSide: Int]) -> Void
    let adjust: (ShoeSide, Int) -> Void
    let prepare: () -> Void
    func makeUIView(context: Context) -> FitTouchSurface { FitTouchSurface() }
    func updateUIView(_ view: FitTouchSurface, context: Context) {
        view.feet = feet; view.travel = travel
        view.change = change; view.commit = commit; view.cancel = cancel; view.adjust = adjust; view.prepare = prepare
        view.updateAccessibility()
    }
}

private final class FitAccessibilityElement: UIAccessibilityElement {
    var increment: (() -> Void)?
    var decrement: (() -> Void)?
    override func accessibilityIncrement() { increment?() }
    override func accessibilityDecrement() { decrement?() }
}

private final class FitTouchSurface: UIView {
    var feet: [ShoeSide: FootState] = [:]
    var travel: CGFloat = 1
    var change: ((ShoeSide, Double) -> Void)?
    var commit: ((ShoeSide) -> Void)?
    var cancel: (([ShoeSide: Int]) -> Void)?
    var adjust: ((ShoeSide, Int) -> Void)?
    var prepare: (() -> Void)?
    private struct Drag {
        let side: ShoeSide
        let startY: CGFloat
        let originals: [ShoeSide: Int]
        var moved = false
    }
    private var drags: [UITouch: Drag] = [:]
    private lazy var leftElement = element(.left)
    private lazy var rightElement = element(.right)
    override init(frame: CGRect) { super.init(frame: frame); isMultipleTouchEnabled = true; backgroundColor = .clear }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    private func element(_ side: ShoeSide) -> FitAccessibilityElement {
        let element = FitAccessibilityElement(accessibilityContainer: self)
        element.accessibilityLabel = "\(side.title) fit"
        element.accessibilityIdentifier = "\(side.rawValue)-fit"
        element.accessibilityTraits = .adjustable
        element.increment = { [weak self] in self?.adjust?(side, 5) }
        element.decrement = { [weak self] in self?.adjust?(side, -5) }
        return element
    }
    func updateAccessibility() {
        for (side, element) in [(ShoeSide.left, leftElement), (.right, rightElement)] {
            let foot = feet[side] ?? FootState()
            element.accessibilityValue = foot.connected ? (foot.hasFitCalibration ? "\(foot.target) percent\(foot.lacing ? ", lacing" : "")" : "Fit setup needed") : "Not connected"
            element.accessibilityHint = "Adjusts this shoe in steps of five percent."
            element.accessibilityTraits = foot.busy || !foot.connected || !foot.hasFitCalibration ? [.adjustable, .notEnabled] : .adjustable
        }
        accessibilityElements = [leftElement, rightElement]
        setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        leftElement.accessibilityFrameInContainerSpace = CGRect(x: 0, y: 0, width: bounds.width / 2, height: bounds.height)
        rightElement.accessibilityFrameInContainerSpace = CGRect(x: bounds.width / 2, y: 0, width: bounds.width / 2, height: bounds.height)
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            let side: ShoeSide = point.x < bounds.midX ? .left : .right
            guard feet[side]?.connected == true, feet[side]?.hasFitCalibration == true, feet[side]?.busy == false,
                  !drags.values.contains(where: { $0.side == side }) else { continue }
            let originals = [side: feet[side]!.target]
            drags[touch] = Drag(side: side, startY: point.y, originals: originals)
            prepare?()
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard var drag = drags[touch] else { continue }
            let distance = drag.startY - touch.location(in: self).y
            if abs(distance) >= 5 { drag.moved = true }
            drags[touch] = drag
            if drag.moved { change?(drag.side, Double(drag.originals[drag.side]!) + Double(distance / max(1, travel)) * 100) }
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesMoved(touches, with: event)
        for touch in touches {
            guard let drag = drags.removeValue(forKey: touch) else { continue }
            if drag.moved { commit?(drag.side) }
        }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { if let drag = drags.removeValue(forKey: touch) { cancel?(drag.originals) } }
    }
}

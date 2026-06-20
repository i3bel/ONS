import SwiftUI

// MARK: - Environment Keys (cilicili 风格浮动标题)

private struct LibraryNavigationTitleHiddenKey: EnvironmentKey {
    static let defaultValue = Binding<Bool>.constant(false)
}

private extension EnvironmentValues {
    var libraryNavigationTitleHidden: Binding<Bool> {
        get { self[LibraryNavigationTitleHiddenKey.self] }
        set { self[LibraryNavigationTitleHiddenKey.self] = newValue }
    }
}

// MARK: - 浮动大标题 View modifier

/// 将 LibraryView 顶部左上角改为 cilicili 风格的浮动大标题。
/// 使用方式：在 NavigationStack 内容上调用 `.libraryFloatingTitle(count:)`
struct LibraryFloatingTitleModifier: ViewModifier {
    let count: Int
    @State private var isTitleHidden = false

    func body(content: Content) -> some View {
        content
            .environment(\.libraryNavigationTitleHidden, $isTitleHidden)
            .safeAreaInset(edge: .top, spacing: 0) {
                LibraryFloatingNavigationTitle(
                    count: count,
                    isTitleHidden: isTitleHidden
                )
            }
    }
}

extension View {
    func libraryFloatingTitle(count: Int) -> some View {
        modifier(LibraryFloatingTitleModifier(count: count))
    }
}

// MARK: - 浮动标题视图（左上角大字 + 动画数字）

private struct LibraryFloatingNavigationTitle: View {
    let count: Int
    let isTitleHidden: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            // AniShelf 风格：大数字 + "takes" 标签
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(count)")
                    .font(.largeTitle.weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(count)))
                Text(animeTitleResource)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .contentTransition(.identity)
            }
            .animation(.bouncy, value: count)
            .opacity(isTitleHidden ? 0 : 1)
            .scaleEffect(isTitleHidden ? 0.92 : 1, anchor: .leading)
            .clipped()

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 2)
        .padding(.bottom, 6)
        .background(.clear)
    }

    private var animeTitleResource: LocalizedStringResource { "takes" }
}

// MARK: - TopScrollEdgeEffect (cilicili 风格，滚动时隐藏大标题)

struct LibraryTopScrollEdgeEffect: ViewModifier {
    @Environment(\.libraryNavigationTitleHidden) private var libraryNavigationTitleHidden

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > 22
            } action: { _, isHidden in
                guard libraryNavigationTitleHidden.wrappedValue != isHidden else { return }
                withAnimation(.smooth(duration: 0.18)) {
                    libraryNavigationTitleHidden.wrappedValue = isHidden
                }
            }
    }
}

extension View {
    func libraryTopScrollEdgeEffect() -> some View {
        modifier(LibraryTopScrollEdgeEffect())
    }
}

// MARK: - LibraryNavigationTitleCapsule (导航栏 principal 位置的精简版)
// 用于多选状态下在导航栏 principal 位置显示已选数量

struct LibraryNavigationTitleCapsule: View {
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("\(count)")
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(count)))
            Text(animeTitleResource)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.identity)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .animation(.bouncy, value: count)
    }

    private var animeTitleResource: LocalizedStringResource { "Anime" }
}

// MARK: - LibraryToolbarSummaryCapsule (cilicili 风格的 filter/sort 胶囊按钮)

struct LibraryToolbarSummaryCapsule: View {
    let primary: LocalizedStringResource

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.92))

            Text(primary)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Circle()
                .fill(.secondary.opacity(0.45))
                .frame(width: 3.5, height: 3.5)

            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 2)
        .minimumScaleFactor(0.82)
    }
}

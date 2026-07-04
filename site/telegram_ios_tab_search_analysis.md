# 实现 iOS 26 Search Tab（参考 cilicili 项目）

## 目标

请按照 iOS 26 官方 Search Tab 的实现方式完成，而不是自己实现一个搜索按钮动画。

参考项目：

* cilicili
* iOS 26 Human Interface Guidelines

最终效果要求：

* 底部使用系统 Tab Bar。
* Search 为系统 Search Tab。
* 点击 Search 后，不进行普通页面切换。
* Search Button 自动 Morph 为长条 Search Bar。
* 使用系统 Liquid Glass 动画。
* 使用系统 Search Transition。
* 不实现任何自定义 Morph 动画。

---

# 不要这样实现

不要：

* 自定义 BottomBar
* 自己写 SearchButton
* GeometryReader
* matchedGeometryEffect
* UIViewPropertyAnimator
* overlay 实现搜索框
* ZStack 做搜索动画
* 手写 Constraint 动画
* 两个 View Fade In / Fade Out

这些都不是 iOS 26 官方方案。

---

# 正确实现方式

Root 页面必须使用：

```swift
TabView(selection: $selection) {

    Tab(value: .home) {
        HomeView()
    }

    Tab(value: .library) {
        LibraryView()
    }

    Tab(
        "Search",
        systemImage: "magnifyingglass",
        value: .search,
        role: .search
    ) {
        SearchView()
    }

    Tab(value: .settings) {
        SettingsView()
    }
}
```

重点：

```swift
role: .search
```

这是整个效果的核心。

不要删除。

---

# SearchView

Search 页面必须使用：

```swift
NavigationStack {

    SearchContentView()

}
.searchable(
    text: $searchText,
    placement: .automatic,
    prompt: "Search"
)
```

不要自己创建搜索框。

不要自己实现 UITextField。

必须使用：

```swift
.searchable(...)
```

---

# 动画来源

动画全部由系统负责。

包括：

* Search Button 展开
* Search Capsule Morph
* Liquid Glass
* Navigation Transition
* Search Focus
* 键盘弹出
* Search Collapse

项目中不要编写任何动画代码来模拟这些行为。

---

# UI 行为

点击 Search Tab 后：

系统自动完成：

```text
Bottom Search Tab

↓

Morph

↓

Navigation Search Bar

↓

Search 获得焦点

↓

键盘弹出
```

关闭搜索后：

```text
Search Bar

↓

Collapse

↓

恢复 Bottom Search Tab
```

整个过程无需手写动画。

---

# SearchContentView

SearchContentView 只负责：

* 搜索结果
* 最近搜索
* 搜索建议
* 空状态
* 网络请求

不要负责：

* Search Bar
* Search Button
* Search Animation

这些由系统负责。

---

# 不需要实现

不要实现：

* SearchBarView
* SearchButtonView
* ExpandAnimation
* CollapseAnimation
* SearchOverlay
* FloatingSearchBar
* CustomNavigationBar
* CustomBottomBar

全部删除。

---

# 技术要求

必须使用：

* SwiftUI
* TabView
* Tab(role: .search)
* NavigationStack
* .searchable()

不要使用：

* UIKit 自定义搜索栏
* UIViewRepresentable（除非项目其它地方必须）
* 第三方 SearchBar

---

# 系统要求

需要：

* Xcode 26
* iOS 26 SDK

运行于 iOS 26 时，应自动获得：

* Liquid Glass
* Search Morph
* Search Transition
* Search Focus Animation

无需手写实现。

---

# 代码风格

整个项目应尽量遵循 Apple 官方 SwiftUI 写法。

Search 的职责划分如下：

* RootTabView：负责 Tab 结构。
* SearchView：负责 NavigationStack 和 `.searchable()`。
* SearchContentView：负责展示搜索内容。
* SearchViewModel：负责搜索逻辑。

所有系统动画交由 iOS 26 Framework 完成，不要重复实现。

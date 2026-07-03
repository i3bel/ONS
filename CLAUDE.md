# RecipeSlate — Crouton 风格食谱 App

## Build

```bash
make build        # 编译
make clean        # 清理
make format       # swift-format
make run-device   # 装到真机
open MyAnimeList.xcodeproj
```

零外部依赖，仅 SwiftUI + 系统框架。

## 3 Tab 架构

| Tab | 文件 | 核心功能 |
|-----|------|----------|
| 食谱 | `Views/Recipe/RecipeShelfView.swift` | Crouton 风格白卡片列表、链式食谱、搜索筛选 |
| 烹饪 | `Views/Recipe/CookModeView.swift` | 全屏分步烹饪、橙色食材高亮点击弹用量、Vision 挥手翻页、语音免触、自命名计时器 |
| 食材 | `Views/Recipe/ShoppingListView.swift` | 跨食谱合并、智能分类 9 档口、Reminders 同步 |

## 数据模型 `Models/RecipeStore.swift`

```
Recipe → id, name, thumbnailFilename, defaultServings, status, ingredients[], steps[], notes
  Ingredient → id, name, amount(基于defaultServings的总量), unit, category, isPrepared
    func amount(forServings:baseServings:) -> String   // 核心缩放公式
  CookingStep → id, order, description, duration?
```

缩放公式：`(ingredient.amount / baseServings) * targetServings` — 简洁、无歧义。

## Crouton 特色功能

| 功能 | 实现方式 |
|------|---------|
| 列表卡片 | 白底 + 90x90 圆角缩略图 + shadow |
| 缩放引擎 | Stepper → 食材列表实时联动，非默认值时 orange 强调色 |
| 链式食谱 | 食材名匹配已有食谱名 → 🔗 胶囊标签跳转 |
| 食材高亮 | 步骤文本中的食材名 orange+bold+underline 显示 |
| 用量弹窗 | 点击文本 → 循环弹出当前步骤各食材的缩放后用量 Popover |
| 命名计时器 | 自动抓取"烘烤 20 分钟"等动作短语命名为按钮标题 |
| 挥手翻页 | Vision VNDetectHumanHandPoseRequest + 前置摄像头 |
| 语音翻页 | SFSpeechRecognizer 监听"下一步/上一步" |
| 跨食谱合并 | 同名+同单位食材合并总量，显示来源 |
| 智能分类 | 50+ 常见食材映射到 9 类档口 |
| 提醒同步 | EventKit EKReminder 一键写入 |

## 手势免触

- `HandGestureManager.swift` — NSObject + AVCaptureVideoDataOutputSampleBufferDelegate
- VNDetectHumanHandPoseRequest 检测手腕位移方向
- 防抖间隔 1 秒，避免误触发

## 文件清单

```
Sources/
├── App/MyAnimeListApp.swift           # 3 Tab 入口
├── Models/RecipeStore.swift           # 所有数据模型 + JSON 持久化
└── Views/Recipe/
    ├── RecipeShelfView.swift           # 食谱列表
    ├── RecipeDetailView.swift          # 详情+编辑器
    ├── CookModeView.swift              # 分步烹饪
    ├── ShoppingListView.swift          # 采购清单
    ├── HandGestureManager.swift        # Vision 挥手检测
    └── UIImagePicker.swift             # 相机拍照
```

## iOS 26+ APIs

- `@Observable` + `@Environment`
- `tabBarMinimizeBehavior(.onScrollDown)`
- `.contentTransition(.numericText())`
- `.sensoryFeedback(.success)`

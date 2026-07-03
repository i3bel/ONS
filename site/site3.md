import SwiftUI

// MARK: - 1. 数据模型与分类逻辑

/// 超市档口分区枚举
enum GroceryCategory: String, CaseIterable, Codable {
    case produce = "🥬 蔬菜沙拉区"
    case meat = "🥩 生鲜肉类区"
    case dairy = "🥛 奶制品与冷藏"
    case pantry = "🧂 粮油调味区"
    case misc = "📦 其他杂项"
}

/// 采购项模型
struct GroceryItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    var amount: Double
    let unit: String
    var isCompleted: Bool = false
    
    // 简易的智能归类引擎（实际开发可接入本地词典或轻量级本地模型）
    var category: GroceryCategory {
        let nameLower = name.lowercased()
        if ["牛肉", "鸡肉", "猪肉", "虾", "肉", "蛋"].contains(where: nameLower.contains) {
            return .meat
        } else if ["奶", "芝士", "黄油", "奶酪"].contains(where: nameLower.contains) {
            return .dairy
        } else if ["菜", "菇", "葱", "蒜", "姜", "番茄", "水果"].contains(where: nameLower.contains) {
            return .produce
        } else if ["糖", "盐", "面粉", "油", "酱油", "醋", "淀粉"].contains(where: nameLower.contains) {
            return .pantry
        } else {
            return .misc
        }
    }
}

// MARK: - 2. 主采购清单视图

struct SmartGroceryListView: View {
    // 模拟从页面一（多个不同食谱）一键导入进来的原始数据
    @State private var rawImportedItems: [GroceryItem] = [
        // 来自食谱 A (舒芙蕾松饼)
        GroceryItem(name: "低筋面粉", amount: 120, unit: "克"),
        GroceryItem(name: "纯牛奶", amount: 80, unit: "毫升"),
        GroceryItem(name: "鸡蛋", amount: 4, unit: "个"),
        GroceryItem(name: "细砂糖", amount: 60, unit: "克"),
        // 来自食谱 B (红烧肉)
        GroceryItem(name: "五花肉", amount: 500, unit: "克"),
        GroceryItem(name: "鸡蛋", amount: 3, unit: "个"), // 与松饼重叠的食材
        GroceryItem(name: "细砂糖", amount: 20, unit: "克"), // 与松饼重叠的食材
        GroceryItem(name: "大葱", amount: 1, unit: "根")
    ]
    
    // 已勾选完成的清单（单独存放或过滤显示）
    @State private var completedItems: Set<UUID> = []
    
    // 计算属性：核心合并与分类引擎（Aggregation & Categorization Engine）
    private var categorizedGroceryList: [GroceryCategory: [GroceryItem]] {
        // 1. 先进行跨食谱合并
        var mergedDict: [String: GroceryItem] = [:]
        
        for item in rawImportedItems {
            // 生成唯一 Key（名称+单位 相同才合并）
            let key = "\(item.name)_\(item.unit)"
            if let existingItem = mergedDict[key] {
                // 如果已存在，数量累加
                mergedDict[key]?.amount += item.amount
            } else {
                mergedDict[key] = item
            }
        }
        
        // 2. 再按超市档口进行分组归类
        var result: [GroceryCategory: [GroceryItem]] = [:]
        for (_, item) in mergedDict {
            var updatedItem = item
            // 同步当前的完成状态
            updatedItem.isCompleted = completedItems.contains(item.id)
            
            result[updatedItem.category, default: []].append(updatedItem)
        }
        
        // 3. 对每组内的食材按名称排序，保证 UI 稳定
        for (cat, items) in result {
            result[cat] = items.sorted(by: { $0.name < $1.name })
        }
        
        return result
    }
    
    var body: some View {
        NavigationView {
            List {
                // 遍历所有有数据的超市档口分类
                ForEach(GroceryCategory.allCases.filter { categorizedGroceryList[$0] != nil }, id: \.self) { category in
                    Section(header: Text(category.rawValue)
                        .font(.marginCallout)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)) {
                            
                            ForEach(categorizedGroceryList[category] ?? []) { item in
                                GroceryRowView(item: item, isCompleted: completedItems.contains(item.id)) {
                                    toggleCompletion(for: item)
                                }
                            }
                        }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("🛒 采购清单")
            .toolbar {
                // 顶部生态联动工具栏
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: syncWithAppleReminders) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                            Text("同步到提醒事项")
                                .font(.footnote)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 交互函数
    
    /// 切换勾选状态（带震动和动画）
    private func toggleCompletion(for item: GroceryItem) {
        // 1. 触发 iOS 原生触觉马达（Taptic Engine）轻微震动
        let impactMed = UIImpactFeedbackGenerator(style: .medium)
        impactMed.impactOccurred()
        
        // 2. 动画化更新状态
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if completedItems.contains(item.id) {
                completedItems.remove(item.id)
            } else {
                completedItems.insert(item.id)
            }
        }
    }
    
    /// 与 iOS 系统原生“提醒事项（Reminders）”App 联动
    private func syncWithAppleReminders() {
        // 这里需要引入 EventKit 框架
        // 商业逻辑：
        // 1. EKEventStore.requestAccess(to: .reminder) 获取苹果官方提醒事项权限
        // 2. 创建一个名为“Crouton 采购清单”的列表
        // 3. 遍历拼接计算好的 categorizedGroceryList 写入系统
        print("正在同步已合并的食材到 iPhone 原生提醒事项...")
    }
}

// MARK: - 3. 单行食材渲染组件 (支持优雅的完成动效)

struct GroceryRowView: View {
    let item: GroceryItem
    let isCompleted: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                // 圆形复选框
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isCompleted ? .green : .secondary)
                    .scaleEffect(isCompleted ? 1.1 : 1.0)
                    .animation(.easeIn(duration: 0.1), value: isCompleted)
                
                // 食材名称
                Text(item.name)
                    .font(.body)
                    .foregroundColor(isCompleted ? .secondary : .primary)
                    .strikethrough(isCompleted, color: .secondary) // 爽快的删除线
                
                Spacer()
                
                // 合并计算后的分量
                HStack(spacing: 2) {
                    Text(formatAmount(item.amount))
                        .font(.body)
                        .fontWeight(.medium)
                    Text(item.unit)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .foregroundColor(isCompleted ? .secondary : .primary)
                .opacity(isCompleted ? 0.5 : 1.0)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain) // 取消 Button 默认的高亮灰色背景
    }
    
    // 隐藏多余小数点的格式化工具
    private func formatAmount(_ amount: Double) -> String {
        return amount.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", amount) : String(format: "%.1f", amount)
    }
}

// MARK: - Font 扩展辅助样式
extension Font {
    static let marginCallout = Font.system(size: 14, weight: .bold, design: .rounded)
}

// MARK: - 4. 预览
struct SmartGroceryListView_Previews: PreviewProvider {
    static var previews: some View {
        SmartGroceryListView()
    }
}
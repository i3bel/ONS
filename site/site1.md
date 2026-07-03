import SwiftUI

// MARK: - 1. 数据模型 (Data Models)

/// 计量单位枚举
enum IngredientUnit: String, Codable, CaseIterable {
    case g = "克"
    case ml = "毫升"
    case pcs = "个"
    case spoon = "勺"
    case pinch = "少许" // 无需缩放的模糊单位
}

/// 单个配料模型
struct Ingredient: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let baseAmount: Double? // 基础份量 (一份的量)，nil 表示“少许/适量”不需要计算
    let unit: IngredientUnit
    
    /// 根据当前的目标份量（人数）计算实际所需量
    func amount(forServings servings: Int, baseServings: Int) -> String {
        guard let baseAmount = baseAmount else {
            return unit.rawValue // 像“少许”这种直接返回单位即可
        }
        
        // 核心缩放公式：(基础量 / 原方人数) * 目标人数
        let calculatedAmount = (baseAmount / Double(baseServings)) * Double(servings)
        
        // 格式化输出：去除末尾无用的 .0
        if calculatedAmount.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", calculatedAmount)
        } else {
            return String(format: "%.1f", calculatedAmount)
        }
    }
}

/// 食谱模型
struct Recipe: Identifiable {
    let id = UUID()
    let title: String
    let imageName: String
    let baseServings: Int // 原方基准人数 (例如：原本是2人份)
    let ingredients: [Ingredient]
}

// MARK: - 2. 模拟数据 (Mock Data)
extension Recipe {
    static let mockPancake = Recipe(
        title: "Crouton 风味舒芙蕾松饼",
        imageName: "flour", 
        baseServings: 2, // 默认是 2 人份
        ingredients: [
            Ingredient(name: "低筋面粉", baseAmount: 60, unit: .g),
            Ingredient(name: "纯牛奶", baseAmount: 40, unit: .ml),
            Ingredient(name: "鸡蛋 (大小适中)", baseAmount: 2, unit: .pcs),
            Ingredient(name: "细砂糖", baseAmount: 30, unit: .g),
            Ingredient(name: "香草精", baseAmount: nil, unit: .pinch) // 适量，不参与计算
        ]
    )
}

// MARK: - 3. 界面与交互 (View Layer)

struct RecipeDetailView: View {
    let recipe: Recipe = .mockPancake
    
    // 状态量：当前用户选择的目标人数（初始值设为食谱的原方人数）
    @State private var currentServings: Int
    
    init() {
        // 初始化状态，使其默认等于食谱的基准人数
        _currentServings = State(initialValue: Recipe.mockPancake.baseServings)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // 1. 食谱顶部美化头图卡片
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(
                            colors: [Color.black.opacity(0.6), Color.clear],
                            startPoint: .bottom,
                            endPoint: .center
                        )
                        .frame(height: 200)
                        .background(Color(.systemGray5)) // 实际开发中替换为 Image
                        .cornerRadius(16)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recipe.title)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("基础配方：\(recipe.baseServings)人份")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    // 2. 核心份量动态缩放控制面板 (Scaling Controller)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("烹饪份量", systemImage: "person.2.fill")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                            
                            // 动态高亮标签
                            Text("\(currentServings) 人份")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(currentServings == recipe.baseServings ? .primary : .accentColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(currentServings == recipe.baseServings ? Color(.systemGray6) : Color.accentColor.opacity(0.12))
                                )
                        }
                        
                        // 缩放 Stepper 计数器
                        Stepper(value: $currentServings, in: 1...20) {
                            Text("调整就餐人数，配料克数自动联动")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // 3. 联动配料表列表 (Ingredients List)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("用料清单")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.bottom, 4)
                        
                        ForEach(recipe.ingredients) { ingredient in
                            HStack {
                                // 食材名称
                                Text(ingredient.name)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                // 动态联动计算后的分量 + 单位
                                HStack(spacing: 2) {
                                    if ingredient.baseAmount != nil {
                                        Text(ingredient.amount(forServings: currentServings, baseServings: recipe.baseServings))
                                            .font(.body)
                                            .fontWeight(.bold)
                                            // 当数字发生改变时，触发高亮强调色，带来精妙的微交互感
                                            .foregroundColor(currentServings == recipe.baseServings ? .primary : .accentColor)
                                            .animation(.easeInOut(duration: 0.2), value: currentServings)
                                    }
                                    
                                    Text(ingredient.unit.rawValue)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 8)
                            Divider()
                        }
                    }
                    .padding(.horizontal)
                    
                }
                .padding(.vertical)
            }
            .navigationTitle("食谱详情")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 4. 预览画布
struct RecipeDetailView_Previews: PreviewProvider {
    static var previews: some View {
        RecipeDetailView()
            .preferredColorScheme(.light)
        RecipeDetailView()
            .preferredColorScheme(.dark)
    }
}
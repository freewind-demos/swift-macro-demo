// swift-macro-demo.swift

import Dispatch
import Observation

// ============ @Observable (Swift 5.9+) ============
@Observable
class User {
    var name: String = "Tom"
    var age: Int = 25
}

let user = User()
print("用户名: \(user.name)")
user.name = "Jerry"
print("修改后: \(user.name)")

// ============ @MainActor ============
@MainActor
class UIManager {
    func updateUI() {
        print("在主线程更新UI")
    }
}

// 在主线程执行
Task { @MainActor in
    let manager = UIManager()
    manager.updateUI()
}

// ============ @resultBuilder ============
// 结果构建器用于创建数组/字典
@resultBuilder
struct StringBuilder {
    static func buildBlock(_ components: String...) -> String {
        components.joined(separator: "\n")
    }

    static func buildIf(_ component: String?) -> String {
        component ?? ""
    }
}

struct Document {
    @StringBuilder var content: String

    init(@StringBuilder content: () -> String) {
        self.content = content()
    }
}

let doc = Document {
    "标题"
    "段落1"
    if false {
        "隐藏内容"
    }
    "段落2"
}
print(doc.content)

// ============ @autoclosure ============
func logIfTrue(_ condition: @autoclosure () -> Bool) {
    if condition() {
        print("条件为真")
    }
}

logIfTrue(2 > 1)

// ============ @escaping ============
func withCompletion(_ completion: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        completion()
    }
}

withCompletion {
    print("完成!")
}

// ============ @propertyWrapper 已在前面演示 ============

// ============ @inlinable ============
@inlinable
public func maxValue<T>(_ a: T, _ b: T) -> T where T: Comparable {
    return a > b ? a : b
}

print("最大值: \(maxValue(5, 10))")

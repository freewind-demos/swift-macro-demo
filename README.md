# Swift 宏/属性 Demo

## 简介

本 demo 展示 Swift 中常用的几个重要特性：@Observable、@MainActor、@resultBuilder、@autoclosure、@escaping、@inlinable 和 @propertyWrapper。这些都是 Swift 开发中非常核心的概念，特别是在 Swift 5.9 引入的宏（Macro）系统后，Swift 的元编程能力得到了大幅提升。

## 基本原理

### 什么是 Swift 宏？

Swift 宏是一种**编译时代码生成**技术，它允许我们在编译阶段自动生成代码。宏的核心思想是：**写一个标记（Annotation），编译器自动展开为实际的代码**。

Swift 的宏分为两种类型：

1. **声明式宏（Declaration Macros）**：以 `@` 开头，如 `@Observable`、`@MainActor`
2. **访问控制宏（Accessor Macros）**：用于生成 getter/setter

宏的工作流程：
```
源代码 → 宏展开 → 生成新代码 → 编译
```

本 demo 将详细介绍这些常用宏的原理和使用方法。

## 启动和使用

### 环境要求

- Swift 5.9+（因为 @Observable 是 Swift 5.9 引入的）
- macOS 或 Linux（需安装 Swift 工具链）

### 安装和运行

```bash
cd swift-macro-demo
swift run
```

运行后可以看到各个宏的输出效果。

---

## 教程

### @Observable —— 响应式编程的革命

#### 为什么需要 @Observable？

在 Swift 5.9 之前，如果我们想让一个类支持响应式更新（比如 UI 自动刷新），通常有几种方式：

1. **手动实现 KVO**（Key-Value Observing）—— 代码繁琐
2. **使用 Combine 框架**—— 需要引入额外的框架
3. **自己实现观察者模式**—— 需要写大量模板代码

@Observable 的出现彻底改变了这一状况。它通过宏自动生成响应式代码，让类天然支持观察者模式。

#### @Observable 的原理

@Observable 是一个**声明式宏**，它在编译时会自动为你的类生成以下代码：

1. **存储属性的 observation 记录**
2. **didSet 的观察者逻辑**
3. **事务（transaction）支持**

看看编译器实际生成的代码大致是什么样的：

```swift
// 你写的代码：
@Observable
class User {
    var name: String = "Tom"
    var age: Int = 25
}

// 编译器大致展开为：
class User {
    // 观察者存储
    private let _name: Storage<String>
    private let _age: Storage<Int>

    // 观察者存储（用于 UI 绑定）
    var name: String {
        get { _name.value }
        set { _name.value = newValue }
    }

    var age: Int {
        get { _age.value }
        set { _age.value = newValue }
    }

    // 初始化方法
    init() {
        _name = Storage(initialValue: "Tom")
        _age = Storage(initialValue: 25)
    }
}
```

#### 使用场景

@Observable 主要用于以下场景：

1. **SwiftUI 数据绑定** —— @Observable 类可以直接用于 SwiftUI 的 `@State`、`@Bindable`
2. **MVVM 架构** —— ViewModel 使用 @Observable，View 自动响应变化
3. **任何需要响应式更新的地方** —— 不需要引入 Combine 或 RxSwift

#### 注意事项

1. **只能用于 class**，不能用于 struct（因为 struct 是值类型，行为不同）
2. **只能修饰整个类**，不能单独修饰某个属性
3. **Swift 5.9+ 才能使用**，旧版本需要使用 ObservableObject

#### 实际使用示例

```swift
@Observable
class User {
    var name: String = "Tom"
    var age: Int = 25
}

let user = User()
print("用户名: \(user.name)")  // 输出: 用户名: Tom
user.name = "Jerry"           // 修改属性
print("修改后: \(user.name)")  // 输出: 修改后: Jerry
```

---

### @MainActor —— 线程安全的守护者

#### 为什么需要 @MainActor？

在 Swift 并发编程中，有一个核心原则：**UI 操作必须在主线程执行**。但在多线程环境下，一不小心就可能在后台线程操作 UI，导致崩溃或异常。

传统做法是使用 `DispatchQueue.main.async`，但这会让代码变得冗长且容易出错。

@MainActor 提供了一种**编译时确保线程安全**的方案。

#### @MainActor 的原理

@MainActor 是一个**全局 actor**，它代表主线程这个"执行上下文"。当一个类、方法或属性标记为 @MainActor 时：

1. **所有成员都自动在主线程执行**
2. **访问这些成员时会自动切换到主线程**
3. **编译器会检查是否有线程安全隐患**

#### 使用方式

**1. 修饰类：整个类的所有成员都在主线程**

```swift
@MainActor
class UIManager {
    func updateUI() {
        print("在主线程更新UI")
    }

    var labelText: String = "Hello"
}

// 任何地方访问 UIManager 的成员，都会自动切换到主线程
Task {
    let manager = UIManager()  // 自动在主线程创建
    await manager.updateUI()   // 自动切换到主线程执行
}
```

**2. 修饰方法：特定方法在主线程执行**

```swift
class DataManager {
    @MainActor
    func saveData() {
        // 这个方法只能在主线程调用
    }
}
```

**3. 在 Task 中使用 @MainActor**

```swift
Task { @MainActor in
    // 这个闭包内的代码都在主线程执行
    let manager = UIManager()
    await manager.updateUI()
}
```

#### 注意事项

1. **@MainActor 方法不能从后台线程直接调用**，否则会报错
2. **如果需要跨线程调用，使用 await 关键字**
3. **在 Swift 6 中，跨线程访问 @MainActor 会导致编译错误**（严格模式）

---

### @resultBuilder —— DSL 的构建基石

#### 什么是 resultBuilder？

@resultBuilder（结果构建器）是 Swift 中用于**构建 DSL（领域特定语言）**的核心技术。它允许我们用一种声明式的语法来创建复杂的数据结构。

@resultBuilder 最著名的应用就是 **SwiftUI**：

```swift
VStack {
    Text("Hello")
    Text("World")
}
```

这个看起来像"语法"的代码，实际上就是通过 @resultBuilder 实现的。

#### resultBuilder 的原理

resultBuilder 的核心思想是：**把一系列代码块转换为一个值**。

它通过几个关键方法来工作：

1. **buildBlock** —— 把多个组件组合成一个
2. **buildIf** —— 处理条件分支（if）
3. **buildOptional** —— 处理可选值（if let）
4. **buildEither** —— 处理 if-else 分支

#### 自定义 resultBuilder 示例

让我们自己实现一个简单的 StringBuilder：

```swift
@resultBuilder
struct StringBuilder {
    // 把多个字符串组合成一个
    static func buildBlock(_ components: String...) -> String {
        components.joined(separator: "\n")
    }

    // 处理 if 语句
    static func buildIf(_ component: String?) -> String {
        component ?? ""
    }
}
```

使用它：

```swift
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
        "隐藏内容"  // 条件为 false，不会被包含
    }
    "段落2"
}

print(doc.content)
```

输出：
```
标题
段落1
段落2
```

#### 使用场景

1. **UI 框架** —— SwiftUI、SwiftUI for UIKit
2. **配置构建器** —— 复杂配置的声明式写法
3. **测试框架** —— XCTest 的某种用法
4. **任何需要链式或声明式构建的场景**

#### 进阶：buildEither

如果想让 resultBuilder 支持 if-else，需要实现 buildEither：

```swift
@resultBuilder
struct ConditionalBuilder {
    static func buildBlock(_ components: String...) -> String {
        components.joined(separator: "\n")
    }

    static func buildEither(first component: String) -> String {
        component
    }

    static func buildEither(second component: String) {
        component
    }
}
```

---

### @autoclosure —— 惰性求值的魔术

#### 为什么需要 @autoclosure？

考虑这样一个函数：

```swift
func logIfTrue(_ condition: Bool) {
    if condition {
        print("条件为真")
    }
}
```

使用时：

```swift
logIfTrue(2 > 1)  // 传入表达式
```

这里的 `2 > 1` 实际上会被**立即求值**，然后再传给函数。但有时我们希望**延迟求值**——只有在真正需要的时候才计算表达式的值。

#### @autoclosure 的作用

@autoclosure 自动把传入的表达式包装成一个闭包，从而实现**惰性求值**。

```swift
func logIfTrue(_ condition: @autoclosure () -> Bool) {
    if condition() {  // 调用时才求值
        print("条件为真")
    }
}
```

使用方式不变：

```swift
logIfTrue(2 > 1)
```

但背后的行为变了：`2 > 1` 不会被立即计算，只有在 `condition()` 被调用时才会计算。

#### 使用场景

1. **日志和调试** —— 只有在开启调试时才计算日志内容
2. **断言和验证** —— 只有在需要验证时才计算
3. **性能优化** —— 避免不必要的计算

#### 注意事项

1. @autoclosure **只能用于函数参数**
2. **会自动把参数包装成 () -> T 类型的闭包**
3. 不要过度使用，否则会影响代码可读性

---

### @escaping —— 闭包的生死符

#### 为什么需要 @escaping？

在 Swift 中，闭包默认是**非逃逸**的，这意味着：

1. 闭包会在函数返回前执行完毕
2. 闭包不会在函数返回后继续存在
3. 编译器可以进行更多优化

但有些场景下，我们需要**让闭包"逃逸"出去**：

```swift
func withCompletion(_ completion: @escaping () -> Void) {
    // 异步操作，completion 会在函数返回后才调用
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        completion()
    }
}
```

如果没有 @escaping，编译器会报错，因为闭包会在函数返回后被调用。

#### @escaping 的作用

@escaping 告诉编译器：

1. **这个闭包可能会在函数返回后被调用**
2. **闭包需要被存储起来（通常存储为属性）**
3. **不要进行某些优化**（因为闭包生命周期变长了）

#### 使用场景

1. **异步回调** —— 网络请求、数据库操作的回调
2. **延迟调用** —— 保存闭包，稍后调用
3. **并发场景** —— Task 中使用的闭包

#### 注意事项

1. **@escaping 闭包中如果使用 self，需要显式引用**
2. **异步函数不需要 @escaping**（因为 async/await 已经处理了生命周期）
3. **@autoclosure 和 @escaping 可以一起使用**

```swift
func asyncLog(_ message: @autoclosure @escaping () -> String) {
    DispatchQueue.main.async {
        print(message())
    }
}
```

---

### @inlinable —— 性能优化的秘密武器

#### 为什么需要 @inlinable？

函数调用是有开销的：
1. **保存寄存器**
2. **跳转指令**
3. **参数传递**

对于一些简单的函数（如 getter、setter、基本数学运算），调用开销可能比函数本身还大。

#### @inlinable 的作用

@inlinable 告诉编译器：**把这个函数的调用"内联"到调用处**，即直接在编译时把函数体替换到调用位置。

```swift
@inlinable
public func maxValue<T>(_ a: T, _ b: T) -> T where T: Comparable {
    return a > b ? a : b
}
```

使用 `maxValue(5, 10)` 时，编译器可能会直接生成 `10`，而不产生函数调用。

#### 使用场景

1. **简单的计算函数** ——  getter、setter、基本运算
2. **泛型函数** —— 泛型函数特别适合内联
3. **库/框架的公共 API** —— 让调用者享受性能提升

#### 注意事项

1. **@inlinable 必须在 public 或 open 的函数上使用**
2. **不能内联有复杂控制流的函数**（递归、大循环等）
3. **过度使用会影响编译时间和调试**
4. **调试时可能看不到内联函数的栈帧**

---

### @propertyWrapper —— 属性装饰器

#### 什么是 @propertyWrapper？

@propertyWrapper 允许我们为属性添加"包装器"，在访问属性时执行自定义逻辑。它是 @Observable 等宏的基础技术。

#### 基本用法

```swift
// 定义一个属性包装器
struct TwelveOrLess {
    private var number: Int = 0

    var wrappedValue: Int {
        get { number }
        set { number = min(newValue, 12)  // 限制最大值
    }
}

// 使用
struct Rectangle {
    @TwelveOrLess var width: Int
    @TwelveOrLess var height: Int
}

var rect = Rectangle()
rect.width = 20
print(rect.width)  // 输出 12（被限制了）
```

#### @propertyWrapper 的原理

当使用 `@TwelveOrLess var width` 时，编译器会：

1. 创建一个隐藏的存储属性 `_width`
2. 生成一个计算属性 `width`，访问 `_width.wrappedValue`

#### 使用场景

1. **属性验证** —— 限制值的范围
2. **延迟计算** —— 第一次访问时才计算
3. **线程安全** —— 访问属性时加锁
4. **用户默认存储** —— 自动读写 UserDefaults

#### @propertyWrapper vs @Observable

- @propertyWrapper：装饰单个属性
- @Observable：装饰整个类，让所有属性都响应式

---

## 关键代码详解

### main.swift 文件

这个文件包含了所有宏的演示代码，让我们逐个解析：

#### @Observable 部分

```swift
@Observable
class User {
    var name: String = "Tom"
    var age: Int = 25
}
```

这里使用 @Observable 修饰类，Swift 编译器会自动生成响应式代码。

#### @MainActor 部分

```swift
@MainActor
class UIManager {
    func updateUI() {
        print("在主线程更新UI")
    }
}
```

使用 Task { @MainActor in } 可以确保闭包内的代码在主线程执行。

#### @resultBuilder 部分

```swift
@resultBuilder
struct StringBuilder {
    static func buildBlock(_ components: String...) -> String {
        components.joined(separator: "\n")
    }

    static func buildIf(_ component: String?) -> String {
        component ?? ""
    }
}
```

这是自定义 resultBuilder 的核心代码，buildBlock 处理多个字符串，buildIf 处理 if 语句。

---

## 总结

Swift 的这些宏和属性大大简化了开发：

1. **@Observable** —— 简洁的响应式编程
2. **@MainActor** —— 安全的线程管理
3. **@resultBuilder** —— 构建 DSL 的利器
4. **@autoclosure** —— 惰性求值优化性能
5. **@escaping** —— 管理闭包生命周期
6. **@inlinable** —— 编译时优化
7. **@propertyWrapper** —— 属性级别的自定义逻辑

掌握这些特性，能够写出更简洁、更高效、更安全的 Swift 代码。

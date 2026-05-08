import Carbon
import Foundation

final class CalculatorEngine {
    enum Operation {
        case add
        case subtract
        case multiply
        case divide
    }

    private(set) var display = "0"
    private(set) var outputText = "0"
    private(set) var isComplete = false
    private var accumulator: Decimal?
    private var pendingOperation: Operation?
    private var startsNewEntry = true
    private var expressionText = ""
    private var memory = Decimal.zero

    var onChange: (() -> Void)?

    func inputDigit(_ digit: Int) {
        resetAfterCompletedResultIfNeeded()
        isComplete = false
        if startsNewEntry {
            display = "\(digit)"
            startsNewEntry = false
        } else if display == "0" {
            display = "\(digit)"
        } else {
            display.append("\(digit)")
        }
        updateExpressionWithDisplay()
        notify()
    }

    func inputDecimalSeparator() {
        resetAfterCompletedResultIfNeeded()
        isComplete = false
        if startsNewEntry {
            display = "0."
            startsNewEntry = false
        } else if !display.contains(".") {
            display.append(".")
        }
        updateExpressionWithDisplay()
        notify()
    }

    func clear() {
        isComplete = false
        display = "0"
        outputText = display
        expressionText = ""
        accumulator = nil
        pendingOperation = nil
        startsNewEntry = true
        notify()
    }

    func toggleSign() {
        isComplete = false
        guard display != "0" else {
            outputText = display
            notify()
            return
        }
        if display.hasPrefix("-") {
            display.removeFirst()
        } else {
            display.insert("-", at: display.startIndex)
        }
        updateExpressionWithDisplay()
        notify()
    }

    func percent() {
        isComplete = false
        let value = currentValue() / Decimal(100)
        display(value)
        updateExpressionWithDisplay()
        startsNewEntry = true
        notify()
    }

    func setOperation(_ operation: Operation) {
        isComplete = false
        if startsNewEntry, pendingOperation != nil {
            pendingOperation = operation
            replaceTrailingOperator(with: operation)
            outputText = expressionText
            notify()
            return
        }

        commitPendingOperation()
        pendingOperation = operation
        startsNewEntry = true
        appendOperator(operation)
        outputText = expressionText
        notify()
    }

    func equals() {
        commitPendingOperation()
        pendingOperation = nil
        startsNewEntry = true
        outputText = display
        expressionText = ""
        isComplete = true
        notify()
    }

    func memoryClear() {
        memory = .zero
    }

    func memoryRecall() {
        isComplete = false
        display(memory)
        expressionText = display
        outputText = display
        startsNewEntry = true
        notify()
    }

    func memoryAdd() {
        memory += currentValue()
    }

    func memorySubtract() {
        memory -= currentValue()
    }

    func backspace() {
        isComplete = false
        guard !startsNewEntry else { return }
        if display.count <= 1 || (display.count == 2 && display.hasPrefix("-")) {
            display = "0"
            startsNewEntry = true
        } else {
            display.removeLast()
        }
        updateExpressionWithDisplay()
        notify()
    }

    func handleKey(_ character: String) -> Bool {
        switch character {
        case "0"..."9":
            inputDigit(Int(character) ?? 0)
        case ".", ",":
            inputDecimalSeparator()
        case "+": setOperation(.add)
        case "-": setOperation(.subtract)
        case "*", "x", "X": setOperation(.multiply)
        case "/": setOperation(.divide)
        case "=", "\r", "\n": equals()
        case "%": percent()
        default:
            return false
        }
        return true
    }

    func handleSpecialKey(_ keyCode: UInt16) -> Bool {
        switch Int(keyCode) {
        case kVK_ANSI_Keypad0:
            inputDigit(0)
        case kVK_ANSI_Keypad1:
            inputDigit(1)
        case kVK_ANSI_Keypad2:
            inputDigit(2)
        case kVK_ANSI_Keypad3:
            inputDigit(3)
        case kVK_ANSI_Keypad4:
            inputDigit(4)
        case kVK_ANSI_Keypad5:
            inputDigit(5)
        case kVK_ANSI_Keypad6:
            inputDigit(6)
        case kVK_ANSI_Keypad7:
            inputDigit(7)
        case kVK_ANSI_Keypad8:
            inputDigit(8)
        case kVK_ANSI_Keypad9:
            inputDigit(9)
        case kVK_ANSI_KeypadDecimal:
            inputDecimalSeparator()
        case kVK_ANSI_KeypadPlus:
            setOperation(.add)
        case kVK_ANSI_KeypadMinus:
            setOperation(.subtract)
        case kVK_ANSI_KeypadMultiply:
            setOperation(.multiply)
        case kVK_ANSI_KeypadDivide:
            setOperation(.divide)
        case kVK_ANSI_KeypadEquals:
            equals()
        case kVK_Delete, kVK_ForwardDelete:
            clear()
        case kVK_ANSI_KeypadEnter, kVK_Return:
            equals()
        default:
            return false
        }
        return true
    }

    private func commitPendingOperation() {
        let current = currentValue()

        guard let operation = pendingOperation, let accumulator else {
            accumulator = current
            return
        }

        let result: Decimal
        switch operation {
        case .add:
            result = accumulator + current
        case .subtract:
            result = accumulator - current
        case .multiply:
            result = accumulator * current
        case .divide:
            result = current == .zero ? .zero : accumulator / current
        }

        self.accumulator = result
        display(result)
    }

    private func currentValue() -> Decimal {
        Decimal(string: display, locale: Locale(identifier: "en_US_POSIX")) ?? .zero
    }

    private func display(_ value: Decimal) {
        display = Self.formatter.string(from: value as NSDecimalNumber) ?? "0"
    }

    private func resetAfterCompletedResultIfNeeded() {
        guard isComplete else { return }
        accumulator = nil
        pendingOperation = nil
        expressionText = ""
        startsNewEntry = true
        display = "0"
    }

    private func updateExpressionWithDisplay() {
        if let operation = pendingOperation, let accumulator {
            expressionText = "\(Self.formatter.string(from: accumulator as NSDecimalNumber) ?? display)\(operation.symbol)\(display)"
        } else {
            expressionText = display
        }
        outputText = expressionText
    }

    private func appendOperator(_ operation: Operation) {
        expressionText = "\(display)\(operation.symbol)"
    }

    private func replaceTrailingOperator(with operation: Operation) {
        if expressionText.isEmpty {
            expressionText = "\(display)\(operation.symbol)"
        } else {
            expressionText.removeLast()
            expressionText.append(operation.symbol)
        }
    }

    private func notify() {
        onChange?()
    }

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 10
        formatter.minimumFractionDigits = 0
        return formatter
    }()
}

private extension CalculatorEngine.Operation {
    var symbol: String {
        switch self {
        case .add:
            "+"
        case .subtract:
            "-"
        case .multiply:
            "x"
        case .divide:
            "/"
        }
    }
}

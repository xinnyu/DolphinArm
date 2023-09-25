import SwiftUI

enum ButtonAction {
    case up
    case down
    case left
    case right
    case reset
    case forward
    case backward
    
    case stop

    case backToOrigin
    case action1
    case action2
    case action3
}

class GameJoystickViewModel: ObservableObject {
    @Published var moveX: Int8 = 0
    @Published var moveY: Int8 = 0
    @Published var moveZ: Int8 = 0

    @Published var gripperValue: Double = 0
    
    private var moveTimer: Timer?

    func handleButtonAction(_ action: ButtonAction) {
        switch action {
        case .up:
            moveY = 1
        case .down:
            moveY = -1
        case .left:
            moveX = -1
        case .right:
            moveX = 1
        case .forward:
            moveZ = 1
        case .backward:
            moveZ = -1
        case .stop:
            moveX = 0
            moveY = 0
            moveZ = 0
        case .reset:
            sendResetCmd()
            return
        default:
            break
        }
        print("xy-log \(action)")
        // 如果定时器不存在，且动作不是.stop，创建并启动定时器
        if moveTimer == nil && action != .stop {
            moveTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { [weak self] _ in
                self?.sendMoveCmd()
            })
        } else {
            stopTimer()
        }
        sendMoveCmd()
    }
    
    func stopTimer() {
        // 停止定时器
        moveTimer?.invalidate()
        moveTimer = nil
    }
    
    var lastData: Data?

    func sendMoveCmd() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        var data = Data()
        data.append(contentsOf: [0xA5, 0xA5, 0x02])
        data.append(UInt8(bitPattern: moveX))
        data.append(UInt8(bitPattern: moveY))
        data.append(UInt8(bitPattern: moveZ))
        
        if lastData == nil || lastData != data {
            self.lastData = data
            // 这里处理发送数据。
            print("xy-log moveX: \(moveX) moveY: \(moveY) moveZ: \(moveZ)")
            BTSearchManager.default.sendDatas([data]) { }
        }
    }
    
    func sendResetCmd() {
        gripperValue = 0
        var data = Data()
        data.append(contentsOf: [0xA5, 0xA5, 0x01, 90, 40, 130, 0, 0])
        // 在这里处理发送数据
        print("xy-log reset")
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
//        UISelectionFeedbackGenerator().selectionChanged()
        BTSearchManager.default.sendDatas([data]) {
            Toast.shared.showComplete(title: "复位成功")
        }
    }
    
    func sendGripperCmd() {
        var data = Data()
        data.append(contentsOf: [0xA5, 0xA5, 0x04])
        data.append(UInt8(gripperValue))
        // 在这里处理发送数据
        BTSearchManager.default.sendDatasWithoutResponse([data]) {
            Toast.shared.showComplete(title: "发送成功")
        }
    }
}



struct GameJoystickView: View {
    
    @StateObject var viewModel = GameJoystickViewModel()

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.8), Color.blue.opacity(0.2)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            VStack(spacing: 70) {
                DirectionalPad(action: viewModel.handleButtonAction)
                // “前”和“后”按钮
                HStack(spacing: 40) {
                    ActionButton(title: "前", actionType: .forward, action: viewModel.handleButtonAction)
                    ActionButton(title: "后", actionType: .backward, action: viewModel.handleButtonAction)
                }
                SliderView(title: "夹爪", value: $viewModel.gripperValue, range: 0...37) {
                    viewModel.sendGripperCmd()
                }.padding(.horizontal, 30)
            }
        }
        .navigationBarTitle("式教模式", displayMode: .inline)
        .onAppear(perform: {
            Toast.shared.showToast(title: "控制之前请先复位")
        })
    }
}

struct DirectionalPad: View {
    let action: (ButtonAction) -> Void

    var body: some View {
        ZStack {
            Circle()
                .frame(width: 300, height: 300)
                .foregroundColor(Color.blue.opacity(0.5))
                .shadow(radius: 10)
            VStack {
                ArrowButton(direction: "arrow.up", actionType: .up, action: action) {
                    action(.stop)
                }
                Spacer()
                HStack {
                    ArrowButton(direction: "arrow.left", actionType: .left, action: action) {
                        action(.stop)
                    }
                    Spacer()
                    ArrowButton(direction: "arrow.right", actionType: .right, action: action) {
                        action(.stop)
                    }
                }
                Spacer()
                ArrowButton(direction: "arrow.down", actionType: .down, action: action) {
                    action(.stop)
                }
            }
            ResetButton(action: action)
        }
        .frame(width: 300, height: 300)
    }
}

struct ArrowButton: View {
    let direction: String
    let actionType: ButtonAction
    let action: (ButtonAction) -> Void
    let stopAction: () -> Void

    var body: some View {
        Button(action: {}) {
            Image(systemName: direction)
                .resizable()
                .foregroundColor(Color.white.opacity(0.9))
                .frame(width: 30, height: 30)
                .padding(20)
                .shadow(radius: 10)
        }
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { isPressing in
            if isPressing {
                action(actionType)
            } else {
                stopAction()
            }
        }, perform: {})
    }
}

struct ResetButton: View {
    let action: (ButtonAction) -> Void
    
    var body: some View {
        Button(action: {
            action(.reset)
        }) {
            Image(systemName: "arrow.counterclockwise")
                .resizable()
                .foregroundColor(Color.white.opacity(0.9))
                .frame(width: 40, height: 40)
                .padding(25)
                .shadow(radius: 10)
        }
    }
}

struct ActionButton: View {
    let title: String
    let actionType: ButtonAction
    let action: (ButtonAction) -> Void
    var hPadding: CGFloat = 40

    var body: some View {
        Button(action: {}) {
            ActionButtonContent(title: title, hPadding: hPadding)
        }
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { isPressing in
            if isPressing {
                action(actionType)
            } else {
                action(.stop)
            }
        }, perform: {})
    }
}

struct ActionButtonContent: View {
    let title: String
    var hPadding: CGFloat = 40
    
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(Color.white.opacity(0.9))
            .padding(.vertical, 15)
            .padding(.horizontal, hPadding)
            .background(Color.blue.opacity(0.5))
            .cornerRadius(15)
            .shadow(radius: 10)
    }
}

struct GameJoystickView_Previews: PreviewProvider {
    static var previews: some View {
        GameJoystickView()
    }
}

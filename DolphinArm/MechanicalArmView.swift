//
//  MechanicalArmView.swift
//  DolphinArm
//
//  Created by 潘新宇 on 2023/9/20.
//

import SwiftUI

class MechanicalArmViewModel: ObservableObject {
    
    @Published var rotationValue: Double = 90
    @Published var bAxisValue: Double = 40
    @Published var cAxisValue: Double = 130
    @Published var gripperValue: Double = 0
    @Published var linearAxisValue: Double = 0
    
    func backToOrigin() {
        rotationValue = 90
        bAxisValue = 40
        cAxisValue = 130
        gripperValue = 0
        linearAxisValue = 0
        sendMoveCmd()
        sendLineModuleCmd()
    }
    
    func action1() {
        rotationValue = 130
        bAxisValue = 50
        cAxisValue = 75
        gripperValue = 0
        sendMoveCmd()
    }
    
    func action2() {
        rotationValue = 100
        bAxisValue = 60
        cAxisValue = 65
        gripperValue = 15
        sendMoveCmd()
    }
    
    func action3() {
        rotationValue = 50
        bAxisValue = 50
        cAxisValue = 70
        gripperValue = 35
        sendMoveCmd()
    }

    func handleValueChange(for slider: SliderType) {
        if slider == .linearAxis {
            sendLineModuleCmd()
        } else {
            sendMoveCmd()
        }
    }
    
    func sendMoveCmd() {
        var data = Data()
        data.append(contentsOf: [0xA5, 0xA5, 0x01])
        data.append(UInt8(rotationValue))
        data.append(UInt8(bAxisValue))
        data.append(UInt8(cAxisValue))
        data.append(UInt8(gripperValue))
//        let value = Int(linearAxisValue)
//        data.append(contentsOf: withUnsafeBytes(of: value.bigEndian) { Data($0) })
        BTSearchManager.default.sendDatasWithoutResponse([data]) {
            Toast.shared.showComplete(title: "发送成功")
        }
    }
    
    /// 直线模组运动
    func sendLineModuleCmd() {
        let location = Int(linearAxisValue)
        let hlocation = location / 256
        let llocation = location % 256
        var data = Data()
        data.append(contentsOf: [0xA5, 0xA5, 0x03, UInt8(hlocation), UInt8(llocation)])
        BTSearchManager.default.sendDatasWithoutResponse([data]) {
            Toast.shared.showComplete(title: "发送成功")
        }
    }


    func handleButtonAction(_ action: ButtonAction) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        switch action {
        case .backToOrigin:
            backToOrigin()
        case .action1:
            action1()
        case .action2:
            action2()
        case .action3:
            action3()
        default:
            fatalError()
        }
    }

    enum SliderType {
        case rotation, bAxis, cAxis, gripper, linearAxis
    }
}


struct MechanicalArmView: View {
    
    @StateObject var viewModel = MechanicalArmViewModel()
    
    var spacing: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        if screenHeight > 800 {
            return 30
        } else if screenHeight > 680 {
            return 25
        } else {
            return 12
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.8), Color.blue.opacity(0.2)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            VStack(spacing: spacing) {
                Image("armIcon") // 代替机械臂icon
                    .resizable()
                    .clipShape(.rect(cornerSize: CGSize(width: 20, height: 20)))
                    .frame(width: 100, height: 100)
                    .foregroundColor(Color.blue.opacity(0.5))
                    .onTapGesture(count: 3) {
                        HomeViewModel.shared.showPrinter = false
                    }
                
                HStack(spacing: 30) {
                    StandardButton(title: "回原点", action: viewModel.handleButtonAction, actionType: .backToOrigin)
                    .frame(maxWidth: 180)
                    NavigationLink(destination: GameJoystickView()) {
                        StandardButtonContentView(title: "示教模式")
                    }
                    .frame(maxWidth: 180)
                }
                
                Group {
                    SliderView(title: "旋转", value: $viewModel.rotationValue, range: 0...180) {
                        viewModel.handleValueChange(for: .rotation)
                    }
                    SliderView(title: "B轴", value: $viewModel.bAxisValue, range: 0...80) {
                        viewModel.handleValueChange(for: .bAxis)
                    }
                    SliderView(title: "C轴", value: $viewModel.cAxisValue, range: 55...180) {
                        viewModel.handleValueChange(for: .cAxis)
                    }
                    SliderView(title: "夹爪", value: $viewModel.gripperValue, range: 0...37) {
                        viewModel.handleValueChange(for: .gripper)
                    }
                    SliderView(title: "直线轴", value: $viewModel.linearAxisValue, range: 0...1500, onSlideEnded: {
                        viewModel.handleValueChange(for: .linearAxis)
                    }, unitString: "")
                }
                
                HStack(spacing: 15) {
                    StandardButton(title: "动作1", action: viewModel.handleButtonAction, actionType: .action1)
                    StandardButton(title: "动作2", action: viewModel.handleButtonAction, actionType: .action2)
                    StandardButton(title: "动作3", action: viewModel.handleButtonAction, actionType: .action3)
                }
                .padding(.top, 20)
            }
            .padding()
        }
        .accentColor(.blue.opacity(0.8))
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct StandardButton: View {
    let title: String
    let action: (ButtonAction) -> Void
    let actionType: ButtonAction

    var body: some View {
        Button(action: {
            action(actionType)
        }) {
            StandardButtonContentView(title: title)
        }
        .frame(maxWidth: .infinity)
    }
}

struct StandardButtonContentView: View {
    let title: String

    var body: some View {
        HStack {
            Spacer()
            Text(title)
                .font(.headline)
                .foregroundColor(Color.white.opacity(0.9))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(Color.blue.opacity(0.5))
        .cornerRadius(15)
        .shadow(radius: 10)
        .frame(maxWidth: .infinity)
    }
}

struct SliderView: View {
    let title: String
    let unitString: String
    @Binding var value: Double
    @State private var previousValue: Double = 0
    var range: ClosedRange<Double>
    var onSlideEnded: (() -> Void)?
    
    // 震动反馈生成器
    private let feedbackGenerator = UISelectionFeedbackGenerator()
    
    init(title: String, value: Binding<Double>, range: ClosedRange<Double>, onSlideEnded: (() -> Void)? = nil, unitString: String = "°") {
        self.title = title
        _value = value
        self.range = range
        self.onSlideEnded = onSlideEnded
        self.unitString = unitString
        feedbackGenerator.prepare() // 提前准备，减少震动的启动延迟
    }
    
    var body: some View {
        VStack {
            Text("\(title) (\(Int(range.lowerBound))\(unitString)-\(Int(range.upperBound))\(unitString)): \(Int(value))\(unitString)")
                .foregroundColor(Color.white.opacity(0.9))
            Slider(value: $value, in: range, step: 1, onEditingChanged: { isEditing in
                if !isEditing {
                    onSlideEnded?()
                }
            })
            .onChange(of: value) { newValue in
                if abs(newValue - previousValue) >= 1 { // 调整此阈值以更改震动的频率
                    feedbackGenerator.selectionChanged()
                    previousValue = newValue
                }
            }
            .accentColor(Color.blue)
        }
    }
}


struct MechanicalArmView_Previews: PreviewProvider {
    static var previews: some View {
        MechanicalArmView()
    }
}

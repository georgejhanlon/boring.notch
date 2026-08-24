//
//  BoringHeader.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import Defaults
import SwiftUI

struct BoringHeader: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @StateObject var tvm = ShelfStateViewModel.shared
    var body: some View {
        HStack(spacing: 0) {
            HStack {
                if (!tvm.isEmpty || coordinator.alwaysShowTabs) && Defaults[.boringShelf] {
                    TabSelectionView()
                } else if vm.notchState == .open {
                    EmptyView()
                }
            }
            // Centre the tabs in the space between the notch's left edge and the
            // physical notch, rather than hugging the far-left edge.
            .frame(maxWidth: .infinity, alignment: .center)
            .opacity(vm.notchState == .closed ? 0 : 1)
            .blur(radius: vm.notchState == .closed ? 20 : 0)
            .zIndex(2)

            if vm.notchState == .open {
                Rectangle()
                    .fill(NSScreen.screen(withUUID: coordinator.selectedScreenUUID)?.safeAreaInsets.top ?? 0 > 0 ? .black : .clear)
                    .frame(width: vm.closedNotchSize.width)
                    .mask {
                        NotchShape()
                    }
            }

            HStack(spacing: 2) {
                if vm.notchState == .open {
                    if isOSDType(coordinator.sneakPeekState(for: vm.screenUUID).type) && coordinator.shouldShowSneakPeek(on: vm.screenUUID) && Defaults[.showOpenNotchOSD] {
                        OpenNotchOSD(
                             type: coordinator.binding(for: vm.screenUUID).type,
                             value: coordinator.binding(for: vm.screenUUID).value,
                             icon: coordinator.binding(for: vm.screenUUID).icon,
                             accent: coordinator.binding(for: vm.screenUUID).accent
                        )
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    } else {
                        Button(action: {
                            withAnimation(.smooth) {
                                coordinator.currentView = coordinator.currentView == .timer ? .home : .timer
                            }
                        }) {
                            Capsule()
                                .fill(coordinator.currentView == .timer ? Color(nsColor: .secondarySystemFill) : .black)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    Image(systemName: "timer")
                                        .foregroundColor(coordinator.currentView == .timer ? .claudeOrange : .gray)
                                        .imageScale(.medium)
                                }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Focus timer")

                        Button(action: {
                            withAnimation(.smooth) {
                                coordinator.currentView = coordinator.currentView == .claude ? .home : .claude
                            }
                        }) {
                            Capsule()
                                .fill(coordinator.currentView == .claude ? Color(nsColor: .secondarySystemFill) : .black)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    ClaudeMark(size: 15, color: coordinator.currentView == .claude ? .claudeOrange : .gray)
                                }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Claude")

                        if Defaults[.showMirror] {
                            Button(action: {
                                vm.toggleCameraPreview()
                            }) {
                                Capsule()
                                    .fill(vm.isCameraExpanded ? Color(nsColor: .secondarySystemFill) : .black)
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        Image(systemName: "web.camera")
                                            .foregroundColor(vm.isCameraExpanded ? .green : .gray)
                                            .padding()
                                            .imageScale(.medium)
                                    }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        if Defaults[.showBatteryIndicator] {
                            BoringBatteryView(
                                batteryWidth: 30,
                                isCharging: batteryModel.isCharging,
                                isInLowPowerMode: batteryModel.isInLowPowerMode,
                                isPluggedIn: batteryModel.isPluggedIn,
                                levelBattery: batteryModel.levelBattery,
                                maxCapacity: batteryModel.maxCapacity,
                                timeToFullCharge: batteryModel.timeToFullCharge,
                                timeToDischarge: batteryModel.timeToDischarge,
                                maxAdapterWatts: batteryModel.maxAdapterWatts,
                                isForNotification: false
                            )
                        }
                    }
                }
            }
            .font(.system(.headline, design: .rounded))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .opacity(vm.notchState == .closed ? 0 : 1)
            .blur(radius: vm.notchState == .closed ? 20 : 0)
            .zIndex(2)
        }
        .foregroundColor(.gray)
        .environmentObject(vm)
    }

    func isOSDType(_ type: SneakContentType) -> Bool {
        switch type {
        case .volume, .brightness, .backlight, .mic:
            return true
        default:
            return false
        }
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel())
}

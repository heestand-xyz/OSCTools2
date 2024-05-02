//
//  Created by Heestand XYZ on 2020-11-25.
//  Copyright © 2020 Anton Heestand. All rights reserved.
//

import SwiftUI

public struct OSCInfoView<Leading: View, Trailing: View>: View {
    
    @ObservedObject var osc: OSC
    @ObservedObject var settings: OSCSettings
    @ObservedObject var connection: OSCConnection
    @Binding var active: Bool
    @Binding var color: Color
    let larger: Bool
    
    let leading: () -> Leading
    let trailing: () -> Trailing

    public init(osc: OSC,
                active: Binding<Bool> = .constant(true),
                color: Binding<Color> = .constant(.accentColor),
                larger: Bool = false,
                @ViewBuilder leading: @escaping () -> Leading = { EmptyView() },
                @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.osc = osc
        settings = osc.settings
        connection = osc.connection
        _active = active
        _color = color
        self.larger = larger
        self.leading = leading
        self.trailing = trailing
    }
    
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) var sizeClass
    #endif
    @Environment(\.colorScheme) var colorScheme
    
    public var body: some View {
        ZStack {
#if os(visionOS)
            Color.black
                .opacity(0.33)
                .layoutPriority(-1.0)
#else
            Color.primary
                .opacity(colorScheme == .light ? 0.035 : 0.075)
                .layoutPriority(-1.0)
#endif
            ZStack {
                LinearGradient(gradient: Gradient(colors: [color, color.opacity(0.0)]),
                               startPoint: .leading, endPoint: .trailing)
                    .opacity(osc.recentInput ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.25))
                LinearGradient(gradient: Gradient(colors: [color.opacity(0.0), color]),
                               startPoint: .leading, endPoint: .trailing)
                    .opacity(osc.recentOutput ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.25))
            }
            .layoutPriority(-1)
            .opacity(0.25)
            info
                .padding(.vertical, 3.0)
#if os(visionOS)
                .offset(y: 1.5)
#else
                .offset(y: 3.0)
#endif
        }
    }
    var info: some View {
        GeometryReader { geo in
            #if !os(macOS)
            if sizeClass == .compact {
                stackH(size: geo.size)
            } else {
                stackZ(size: geo.size)
            }
            #else
            if geo.size.width < 400 {
                stackH(size: geo.size)
            } else {
                stackZ(size: geo.size)
            }
            #endif
        }
        .font(.system(size: larger ? 15 : 12, weight: .regular, design: .monospaced))
        .padding(.horizontal)
        .frame(height: 20)
    }
    func stackH(size: CGSize) -> some View {
        HStack {
            left(size: size)
            leading()
            Spacer(minLength: 0)
            center(size: size)
            Spacer(minLength: 0)
            trailing()
            right(size: size)
        }
    }
    func stackZ(size: CGSize) -> some View {
        ZStack {
            HStack {
                left(size: size)
                leading()
                Spacer()
                trailing()
                right(size: size)
            }
            HStack {
                center(size: size)
            }
        }
    }
    func left(size: CGSize) -> some View {
        HStack(spacing: 4) {
            Text(settings.clientAddress)
                .lineLimit(1)
                .contextMenu {
                    Button {
                        copyToClipboard(settings.clientAddress)
                    } label: {
                        Text("Copy Client IP Address")
                    }
                }
            Text(":" + String(describing: settings.clientPort))
                .padding(.leading, -4)
                .foregroundColor(.gray)
                .contextMenu {
                    Button {
                        copyToClipboard("\(settings.clientPort)")
                    } label: {
                        Text("Copy Client Port")
                    }
                }
        }
    }
    func center(size: CGSize) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "radiowaves.left")
                .foregroundColor(osc.recentOutput ? color : .gray)
            Text("OSC")
                .foregroundColor(osc.recentInput || osc.recentOutput ? color : .gray)
            Image(systemName: "radiowaves.right")
                .foregroundColor(osc.recentInput ? color : .gray)
        }
        .opacity(active ? 1.0 : 0.0)
    }
    func right(size: CGSize) -> some View {
        HStack(spacing: 4) {
            Image(systemName: connection.wifi == true ? "wifi" : connection.cellular == true ? "antenna.radiowaves.left.and.right" : "wifi.slash")
                .foregroundColor(connection.wifi == true || connection.cellular == true ? .primary : .gray)
            Text(connection.currentIpAddress ?? "offline")
                .lineLimit(1)
                .contextMenu {
                    if let ipAddress: String = connection.currentIpAddress {
                        Button {
                            copyToClipboard(ipAddress)
                        } label: {
                            Text("Copy Server IP Address")
                        }
                    }
                }
            Text(":" + {
                var port: String = String(describing: settings.serverPort)
                while (port.count < 4) { port = "\(port) " }
                return port
            }())
                .padding(.leading, -4)
                .foregroundColor(.gray)
                .contextMenu {
                    Button {
                        copyToClipboard("\(settings.serverPort)")
                    } label: {
                        Text("Copy Server Port")
                    }
                }
        }
    }
    
    func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}

struct OSCInfoView_Previews: PreviewProvider {
    static var previews: some View {
        OSCInfoView(osc: OSC())
    }
}

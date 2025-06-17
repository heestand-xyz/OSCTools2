//
//  Created by Heestand XYZ on 2020-11-25.
//  Copyright © 2020 Anton Heestand. All rights reserved.
//

import Foundation
import Connectivity
import Logger
import Combine
import SystemConfiguration.CaptiveNetwork
import Network

@MainActor
@Observable
public class OSCConnection {
    
    public private(set) var status: ConnectivityStatus = .determining
    
    public enum State: Equatable {
        public enum Connection {
            case wifi
            case cellular
            case ethernet
        }
        case connected(Connection, withInternet: Bool)
        case disconnected
        case determining
        public var isOnline: Bool {
            if case .connected(let connection, let withInternet) = self {
                return withInternet
            }
            return false
        }
    }
    
    public var state: State {
        switch status {
        case .connected, .connectedViaWiFi:
            return .connected(.wifi, withInternet: true)
        case .connectedViaCellular:
            return .connected(.cellular, withInternet: true)
        case .connectedViaEthernet:
            return .connected(.ethernet, withInternet: true)
        case .connectedViaWiFiWithoutInternet:
            return .connected(.wifi, withInternet: false)
        case .connectedViaCellularWithoutInternet:
            return .connected(.cellular, withInternet: false)
        case .connectedViaEthernetWithoutInternet:
            return .connected(.ethernet, withInternet: false)
        case .notConnected:
            return .disconnected
        case .determining:
            return .determining
        }
    }
    
    @available(*, deprecated)
    public var wifi: Bool {
        if case .connected(let connection, _) = state {
            return connection == .wifi
        }
        return false
    }
    
    @available(*, deprecated)
    public var cellular: Bool {
        if case .connected(let connection, _) = state {
            return connection == .cellular
        }
        return false
    }
    
    public var currentIpAddress: String?
    public private(set) var allIpAddresses: [String] = []
    
    private let connectivity = Connectivity()
    
    public init() {
        Logger.log(frequency: .verbose)
       
        check()
        start()
    }
    
    func setCurrent(ipAddress: String) {
        Logger.log(arguments: ["ipAddress": ipAddress], frequency: .verbose)
        guard allIpAddresses.contains(ipAddress) else { return }
        currentIpAddress = ipAddress
    }
    
    func resetCurrentIPAddress() {
        Logger.log(frequency: .verbose)
        currentIpAddress = nil
        check()
    }
    
    public func start() {
        Logger.log(frequency: .verbose)
        
        connectivity.startNotifier()
        
        connectivity.whenConnected = { [weak self] connectivity in
            self?.status = connectivity.status
            self?.check()
        }
        
        connectivity.whenDisconnected = { [weak self] connectivity in
            self?.status = connectivity.status
            self?.check()
        }
    }
    
    public func stop() {
        Logger.log(frequency: .verbose)
        connectivity.stopNotifier()
    }
    
    /// Check IP Address
    public func check() {
#if !targetEnvironment(simulator)
        let addresses = getAddresses()
        var targetIPAddress: String?
        let mainTargets: [String] = ["192.168"]
        loop: for target in mainTargets {
            for address in addresses {
                if address.hasPrefix(target) {
                    targetIPAddress = address
                    break loop
                }
            }
        }
        if targetIPAddress == nil {
            let subTargets: [String] = ["192.168", "172", "10"]
            loop: for target in subTargets {
                for address in addresses {
                    if address.hasPrefix(target) {
                        targetIPAddress = address
                        break loop
                    }
                }
            }
        }
        if let currentIpAddress: String = currentIpAddress {
            if !addresses.contains(currentIpAddress) {
                self.currentIpAddress = targetIPAddress ?? addresses.first
            }
        } else {
            self.currentIpAddress = targetIPAddress ?? addresses.first
        }
        self.allIpAddresses = addresses
        Logger.log(arguments: ["addresses": addresses, "targetAddress": targetIPAddress], frequency: .verbose)
#endif
    }
    
    private func getAddresses() -> [String] {
        var addresses = [String]()

        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return [] }
        guard let firstAddr = ifaddr else { return [] }

        // For each interface ...
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            var addr = ptr.pointee.ifa_addr.pointee

            // Check for running IPv4, IPv6 interfaces. Skip the loopback interface.
            if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                if addr.sa_family == UInt8(AF_INET) || addr.sa_family == UInt8(AF_INET6) {

                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if (getnameinfo(&addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST) == 0) {
                        let address = String(cString: hostname)
                        addresses.append(address)
                    }
                }
            }
        }

        freeifaddrs(ifaddr)
        return addresses.filter { address in
            address.contains(".")
        }
    }
}

//
//  Created by Heestand XYZ on 2020-11-25.
//  Copyright © 2020 Anton Heestand. All rights reserved.
//

import Foundation
import Reachability
import Logger
import Combine

public class OSCConnection: ObservableObject {
    
    public enum State {
        case wifi
        case cellular
        case offline
    }
    public var state: State {
        if wifi == true {
            .wifi
        } else if cellular == true {
            .cellular
        } else {
            .offline
        }
    }
    
    @Published public var wifi: Bool?
    @Published public var cellular: Bool?
    
    @Published public var currentIpAddress: String?
    @Published public private(set) var allIpAddresses: [String] = []

    var reachability: Reachability?
    
    public init() {
        Logger.log(frequency: .verbose)
       
#if !targetEnvironment(simulator)
        reachability = try? Reachability()
#endif
        
        check()
        monitor()
        
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
    
    /// Monitor WiFi and Cellular
    public func monitor() {
        Logger.log(frequency: .verbose)
        
        reachability?.whenReachable = { [weak self] reachability in
            self?.wifi = reachability.connection == .wifi
            self?.cellular = reachability.connection == .cellular
            self?.check()
        }
        reachability?.whenUnreachable = { [weak self] _ in
            self?.wifi = false
            self?.cellular = false
            self?.check()
        }

        do {
            try reachability?.startNotifier()
        } catch {
            Logger.log(.error(error), message: "Unable to start notifier", frequency: .verbose)
        }
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
            let subTargets: [String] = ["192", "172", "127", "10"]
            loop: for target in subTargets {
                for address in addresses {
                    let address_components = address.components(separatedBy: ".")
                    if address_components.first == target {
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
    
    func stop() {
        Logger.log(frequency: .verbose)
        reachability?.stopNotifier()
    }
    
    func getAddresses() -> [String] {
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

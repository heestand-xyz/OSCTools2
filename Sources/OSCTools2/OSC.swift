//
//  Created by Heestand XYZ on 2020-11-26.
//  Copyright © 2020 Anton Heestand. All rights reserved.
//

import SwiftUI
import OSCKit
import Logger
import Combine

public class OSC: ObservableObject, OSCSettingsDelegate {
    
    let queue: DispatchQueue
    
    public let connection: OSCConnection = .init()
    public let settings: OSCSettings = .init()
    
    #if !targetEnvironment(simulator)
    var client: OSCClient?
    var server: OSCServer?
    #endif
    
    let localNetworkAuthorization = LocalNetworkAuthorization()

    private var isRunning: Bool = false
    
    @Published public var isServerPortOpen: Bool!
    
    @Published public var recentInput: Bool = false
    @Published public var recentOutput: Bool = false
    var recentInputTimer: Timer?
    var recentOutputTimer: Timer?
    
    var listeners: [UUID: (_ address: String, _ values: [any OSCValue]) -> ()] = [:]
    
    public var active: Bool = true {
        didSet {
            if active {
                start()
            } else {
                stop()
            }
        }
    }
    
    var gate: Bool = false
    var lastValuesReceived: [String: String] = [:]
    
    // MARK: - Life Cycle -
    
    public init(queue: DispatchQueue = .main) {
        self.queue = queue
        setup()
        listenToApp()
    }
    
    // MARK: - Setup
    
    private func setup() {
        
#if !targetEnvironment(simulator)
        client = nil
        server = nil
                
        client = OSCClient()
        
        server = OSCServer(port: UInt16(settings.serverPort), receiveQueue: queue, dispatchQueue: queue)
#endif
        
#if !targetEnvironment(simulator)
        isServerPortOpen = OSC.isPortOpen(port: in_port_t(settings.serverPort))
#else
        isServerPortOpen = false
#endif
        
        settings.delegate = self

#if !targetEnvironment(simulator)
        server!.setHandler { [weak self] message, timeTag in
            self?.take(message: message)
        }
#endif
        
        start()
        
        if let serverIPAddress: String = settings.preferredServerAddress {
            connection.check()
            if connection.allIpAddresses.contains(serverIPAddress){
                connection.setCurrent(ipAddress: serverIPAddress)
            }
        }
    }
    
    // MARK: - Tear Down
    
    private func tearDown() {
        stop()
#if !targetEnvironment(simulator)
        client = nil
        server = nil
#endif
    }
    
    // MARK: - App IO
    
    func listenToApp() {
        
        #if !os(macOS)
        
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        #else
        
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: NSApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willResignActive), name: NSApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willTerminate), name: NSApplication.willTerminateNotification, object: nil)
        
        #endif
        
    }
    
    @objc func didBecomeActive() {
        
        #if !os(macOS)
        start()
        #endif
        
        connection.monitor()
        connection.check()
    }
    
    @objc func willResignActive() {
        
        #if !os(macOS)
        stop()
        #endif
    }
    
    @objc func willEnterForeground() {}
    
    @objc func didEnterBackground() {}
    
    @objc func willTerminate() {
        stop()
    }
    
    // MARK: - Set Preferred
    
    public func setPreferred(ipAddress: String) {
        connection.setCurrent(ipAddress: ipAddress)
        settings.preferredServerAddress = ipAddress
    }
    
    public func resetPreferredIPAddress() {
        connection.resetCurrentIPAddress()
        settings.preferredServerAddress = nil
    }
    
    // MARK: - Listen
    
    public func unlisten(id: UUID) {
        listeners.removeValue(forKey: id)
    }
    
    @discardableResult
    public func backgroundListen<T: OSCType>(
        to address: @escaping () -> (String),
        _ callback: @escaping (T) -> ()
    ) -> UUID {
        backgroundListenToAny(to: address) { value in
            callback(T.convert(value: value))
        }
    }
    
    @discardableResult
    public func backgroundListenToArray<T: OSCType>(
        to address: @escaping () -> (String),
        _ callback: @escaping ([T]) -> ()
    ) -> UUID {
        backgroundListenToAnyArray(to: address) { values in
            callback(values.map({ T.convert(value: $0) }))
        }
    }
    
    @discardableResult
    public func backgroundListenToAny(
        to address: @escaping () -> (String),
        _ callback: @escaping (any OSCValue) -> ()
    ) -> UUID {
        let id = UUID()
        listeners[id] = { [weak self] valueAddress, values in
            guard let self = self else { return }
            guard self.wildcardMatch(valueAddress, with: address()) else { return }
            guard let value: any OSCValue = values.first else { return }
            callback(value)
        }
        return id
    }
    
    @discardableResult
    public func backgroundListenToAnyArray(
        to address: @escaping () -> (String),
        _ callback: @escaping ([any OSCValue]) -> ()
    ) -> UUID {
        let id = UUID()
        listeners[id] = { [weak self] valueAddress, values in
            guard let self = self else { return }
            guard self.wildcardMatch(valueAddress, with: address()) else { return }
            callback(values)
        }
        return id
    }
    
    @discardableResult
    public func backgroundListenToAll(
        _ callback: @escaping (String, [any OSCValue]) -> ()
    ) -> UUID {
        let id = UUID()
        listeners[id] = callback
        return id
    }
    
    // MARK: - Send
    
    public func send(values: [AnyOSCValue], address: String) {
        
        guard active else { return }
        
        Logger.log(arguments: ["address": address, "values": values], frequency: .loop)
        
#if !targetEnvironment(simulator)
//        CRASH in OSCKit (before Issue-#10) on DispatchQueue.global(qos: .userInteractive).async { [weak self] in
        do {
            let message: OSCMessage = .message(address, values: values)
            try self.client?.send(message, to: settings.clientAddress, port: UInt16(settings.clientPort))
        } catch {
            Logger.log(.error(error), message: "OSC Message Failed to Send", arguments: ["address": address, "values": values])
        }
        DispatchQueue.main.async {
            self.setRecentOutput()
        }
#endif
    }
    
    // MARK: - Take

    public func take(message: OSCMessage) {
        
        guard active else { return }
        
        queue.async { [weak self] in
            
            guard let self = self else { return }
            
            let address: String = message.addressPattern.stringValue
            guard address != "/_samplerate" else { return }
            var values: [any OSCValue] = message.values
            
            Logger.log(arguments: ["address": address, "values": values], frequency: .loop)
            
            values = values.map { self.filterNaN($0) }
            
            for listener in self.listeners {
                listener.value(address, values)
            }
            
        }
        
        /// Indication
        DispatchQueue.main.async { [weak self] in
            self?.setRecentInput()
        }
    }

    public func take(bundle: OSCBundle) {
        
        guard active else { return }
        
        for element in bundle.elements {
            guard let message = element as? OSCMessage else { continue }
            take(message: message)
        }
    }
    
    // MARK: - Wildcard
    
    private func wildcardMatch(_ sourceAddress: String, with targetAddress: String) -> Bool {
        if sourceAddress == targetAddress {
            return true
        }
        var sourceIndex: Int = 0
        var targetIndex: Int = 0
        var inWildcard: Bool = false
        loop: for sourceCharacter in sourceAddress {
            defer {
                sourceIndex += 1
            }
            if sourceCharacter == "*" {
                inWildcard = true
                if sourceAddress.count > sourceIndex + 1 {
                    let nextSourceCharacter = sourceAddress[sourceIndex + 1]
                    while true {
                        guard targetAddress.count > targetIndex else { return false }
                        let targetCharacter = targetAddress[targetIndex]
                        if nextSourceCharacter == targetCharacter {
                            continue loop
                        }
                        targetIndex += 1
                    }
                    continue
                } else {
                    return true
                }
            }
            guard targetAddress.count > targetIndex else { return inWildcard }
            let targetCharacter = targetAddress[targetIndex]
            if targetCharacter != sourceCharacter {
                return false
            }
            targetIndex += 1
        }
        return targetAddress.count == targetIndex
    }
    
    // MARK: - Filter NaN
    
    func filterNaN(_ value: any OSCValue) -> any OSCValue {
        if let cgFloat = value as? CGFloat {
            if !cgFloat.isFinite {
                return CGFloat(0.0)
            }
        } else if let float = value as? Float {
            if !float.isFinite {
                return Float(0.0)
            }
        } else if let double = value as? Double {
            if !double.isFinite {
                return Double(0.0)
            }
        }
        return value
    }
    
    // MARK: - Start / Stop
    
    public func start() {
        if self.isRunning {
            self.stop()
        }
#if !targetEnvironment(simulator)
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            do {
                try server?.start()
                try client?.start()
                DispatchQueue.main.async {
                    self.isRunning = true
                }
            } catch {
                Logger.log(.error(error), frequency: .verbose)
            }
        }
#endif
    }
    
    public func stop() {
#if !targetEnvironment(simulator)
        server?.stop()
        client?.stop()
#endif
        isRunning = false
    }
    
    // MARK: - Recent
    
    func setRecentInput() {
        recentInput = true
        recentInputTimer?.invalidate()
        recentInputTimer = Timer(timeInterval: 0.25, repeats: false, block: {  [weak self] t in
            self?.recentInput = false
        })
        RunLoop.current.add(recentInputTimer!, forMode: .common)
    }
    
    func setRecentOutput() {
        recentOutput = true
        recentOutputTimer?.invalidate()
        recentOutputTimer = Timer(timeInterval: 0.25, repeats: false, block: {  [weak self] t in
            self?.recentOutput = false
        })
        RunLoop.current.add(recentOutputTimer!, forMode: .common)
    }
    
    // MARK: - Authorization
    
    public func authorize(completion: ((Bool) -> ())? = nil) {
        localNetworkAuthorization.requestAuthorization { authorized in
            DispatchQueue.main.async {
                completion?(authorized)
            }
        }
    }
    
    // MARK: - Port
    
    public static func isPortOpen(_ port: Int) -> Bool {
        isPortOpen(port: in_port_t(port))
    }
    
    static func isPortOpen(port: in_port_t) -> Bool {
        
        let socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        if socketFileDescriptor == -1 {
            return false
        }

        var addr = sockaddr_in()
        let sizeOfSockkAddr = MemoryLayout<sockaddr_in>.size
        addr.sin_len = __uint8_t(sizeOfSockkAddr)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = Int(OSHostByteOrder()) == OSLittleEndian ? _OSSwapInt16(port) : port
        addr.sin_addr = in_addr(s_addr: inet_addr("0.0.0.0"))
        addr.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)
        var bind_addr = sockaddr()
        memcpy(&bind_addr, &addr, Int(sizeOfSockkAddr))

        if Darwin.bind(socketFileDescriptor, &bind_addr, socklen_t(sizeOfSockkAddr)) == -1 {
            return false
        }
        let isOpen = Darwin.listen(socketFileDescriptor, SOMAXCONN ) != -1
        Darwin.close(socketFileDescriptor)
        return isOpen
    }
    
    // MARK: - Settings Delegate
    
    public func setting(clientAddress: String) {}
    
    func setting(preferredServerAddress: String?) {}
    
    public func setting(clientPort: Int) {}
    
    public func setting(serverPort: Int) {
        isServerPortOpen = OSC.isPortOpen(port: in_port_t(serverPort))
//        let port = (serverPort >= 1024 && serverPort <= 65_535) ? UInt16(serverPort) : 1024
        tearDown()
        setup()
    }
}

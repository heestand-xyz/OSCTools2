//
//  Created by Heestand XYZ on 2020-11-23.
//  Copyright © 2020 Anton Heestand. All rights reserved.
//

import Foundation
import Combine

protocol OSCSettingsDelegate: AnyObject {
    func setting(clientAddress: String)
    func setting(preferredServerAddress: String?)
    func setting(clientPort: Int)
    func setting(serverPort: Int)
}

public class OSCSettings: ObservableObject {
    
    weak var delegate: OSCSettingsDelegate?
        
    public static let kDefaultClientAddress: String = "localhost"
    public static let kDefaultClientPort: Int = 8000
    public static let kDefaultServerPort: Int = 7000
        
    @Published public var clientAddress: String {
        didSet {
            UserDefaults.standard.set(clientAddress, forKey: "setting-client-address")
            delegate?.setting(clientAddress: clientAddress)
        }
    }
    
    @Published public var preferredServerAddress: String? {
        didSet {
            UserDefaults.standard.set(preferredServerAddress, forKey: "setting-preferred-server-address")
            delegate?.setting(preferredServerAddress: preferredServerAddress)
        }
    }
    
    @Published public var clientPort: Int {
        didSet {
            UserDefaults.standard.set(clientPort, forKey: "setting-client-port")
            delegate?.setting(clientPort: clientPort)
        }
    }
    
    @Published public var serverPort: Int {
        didSet {
            UserDefaults.standard.set(serverPort, forKey: "setting-server-port")
            delegate?.setting(serverPort: serverPort)
        }
    }
    
    init() {
        
        let clientAddress = UserDefaults.standard.string(forKey: "setting-client-address")
        self.clientAddress = clientAddress ?? OSCSettings.kDefaultClientAddress
        
        let preferredServerAddress = UserDefaults.standard.string(forKey: "setting-preferred-server-address")
        self.preferredServerAddress = preferredServerAddress
        
        let clientPort = UserDefaults.standard.integer(forKey: "setting-client-port")
        self.clientPort = clientPort != 0 ? clientPort : OSCSettings.kDefaultClientPort
        
        let serverPort = UserDefaults.standard.integer(forKey: "setting-server-port")
        self.serverPort = serverPort != 0 ? serverPort : OSCSettings.kDefaultServerPort
    }
}
